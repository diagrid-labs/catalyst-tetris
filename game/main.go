package main

import (
	"context"
	"embed"
	"encoding/json"
	"fmt"
	"io/fs"
	"log"
	"math/rand"
	"net"
	"net/http"
	"os"
	"strconv"
	"sync"
	"text/template"
	"time"

	"github.com/dapr/go-sdk/client"
	"github.com/google/uuid"
	socketio "github.com/googollee/go-socket.io"
)

type connection struct {
	id         string
	user       string
	ready      chan struct{}
	tick       chan struct{}
	socket     socketio.Conn
	score      int
	boardState string
}

type session struct {
	lock     sync.RWMutex
	conn1    *connection
	conn2    *connection
	closed   chan struct{}
	seed     uint64
	lastTick time.Time
}

func (s *session) connFromID(id string) *connection {
	if s.conn1.id == id {
		return s.conn1
	}
	return s.conn2
}

func (s *session) oponentConnFromID(id string) *connection {
	if s.conn1.id == id {
		return s.conn2
	}
	return s.conn1
}

var (
	activeSessions = make(map[string]*session)
	lock           sync.RWMutex
	//go:embed assets/*
	content embed.FS

	//go:embed index.html.tmpl
	tmplContent embed.FS
)

type eventData struct {
	SessionID string
	Data      string
}

type gameResult struct {
	User   string
	Winner bool
	Score  int
}

func main() {
	gameHost, ok := os.LookupEnv("GAME_HOST")
	if !ok {
		gameHost = "localhost:8000"
	}
	lobbyHost, ok := os.LookupEnv("LOBBY_HOST")
	if !ok {
		lobbyHost = "localhost:5000"
	}

	server := socketio.NewServer(nil)
	rand.NewSource(time.Now().UnixNano())

	client, err := client.NewClient()
	if err != nil {
		log.Fatalf("failed to create dapr client: %s", err)
	}
	fmt.Println("client created")

	server.OnConnect("/", func(s socketio.Conn) error {
		lock.Lock()
		defer lock.Unlock()
		fmt.Println("connected:", s.ID())
		return nil
	})

	server.OnError("/", func(s socketio.Conn, e error) {
		fmt.Printf("event error: %s: %s\n", s.ID(), e)
	})

	server.OnDisconnect("/", func(s socketio.Conn, reason string) {
		lock.Lock()
		defer lock.Unlock()

		fmt.Println("closed", reason)

		var session *session
		for _, sess := range activeSessions {
			if sess.conn1.id == s.ID() {
				session = sess
				break
			}
			if sess.conn2.id == s.ID() {
				session = sess
				break
			}
		}

		if session == nil {
			return
		}

		socket := session.oponentConnFromID(s.ID()).socket
		if socket != nil {
			socket.Emit("opponent-disconnected")
		}

		select {
		case <-session.closed:
		default:
			close(session.closed)
		}
	})

	server.OnEvent("/", "i-lose", func(s socketio.Conn, e eventData) {
		lock.RLock()
		defer lock.RUnlock()
		fmt.Printf("i-lose: %s\n", s.ID())

		session, ok := activeSessions[e.SessionID]
		if !ok {
			return
		}

		score, err := strconv.Atoi(e.Data)
		if err != nil {
			fmt.Printf("failed to parse score %s: %s\n", s.ID(), err)
			return
		}
		session.connFromID(s.ID()).score = score
		conn := session.oponentConnFromID(s.ID())
		conn.socket.Emit("you-win")
	})

	server.OnEvent("/", "i-win", func(s socketio.Conn, e eventData) {
		lock.Lock()
		defer lock.Unlock()

		session, ok := activeSessions[e.SessionID]
		if !ok {
			return
		}

		delete(activeSessions, e.SessionID)

		score, err := strconv.Atoi(e.Data)
		if err != nil {
			fmt.Printf("failed to parse score %s: %s\n", s.ID(), err)
			return
		}
		conn := session.connFromID(s.ID())
		conn.score = score
		oppConn := session.oponentConnFromID(s.ID())
		fmt.Printf("i-win: %s %s %d %d\n", s.ID(), conn.user, session.conn1.score, session.conn2.score)

		log.Printf("publishing score for winner: %s\n", conn.user)
		err = client.PublishEvent(context.Background(), "scorepubsub", "scoreupdates", []gameResult{
			{
				User:   conn.user,
				Winner: true,
				Score:  conn.score,
			},
			{
				User:   oppConn.user,
				Winner: false,
				Score:  oppConn.score,
			},
		})
		if err != nil {
			fmt.Printf("failed to publish score: %s\n", err)
		}
	})

	server.OnEvent("/", "ready-init", func(s socketio.Conn, e eventData) {
		lock.RLock()
		session := activeSessions[e.SessionID]
		lock.RUnlock()

		if session == nil {
			fmt.Printf("session not found: %s\n", s.ID())
			return
		}

		session.lock.Lock()
		var conn *connection
		if session.conn1.user == e.Data {
			conn = session.conn1
		} else {
			conn = session.conn2
		}
		conn.socket = s
		conn.id = s.ID()
		close(conn.ready)
		session.lock.Unlock()

		for _, ch := range []chan struct{}{
			session.conn1.ready,
			session.conn2.ready,
		} {
			select {
			case <-ch:
			case <-session.closed:
			}
		}

		s.Emit("randSeed", session.seed)
		s.Emit("draw")
	})

	server.OnEvent("/", "ready", func(s socketio.Conn, e eventData) {
		lock.RLock()
		var session *session

		session, ok := activeSessions[e.SessionID]
		if !ok {
			lock.RUnlock()
			fmt.Printf("session not found: %s\n", s.ID())
			return
		}
		conn := session.connFromID(s.ID())
		oponentConn := session.oponentConnFromID(s.ID())
		lock.RUnlock()

		session.lock.Lock()
		if now := time.Now(); now.Before(session.lastTick.Add(time.Second / 75)) {
			time.Sleep((time.Second / 75) - (now.Sub(session.lastTick)))
		}
		session.lastTick = time.Now()
		conn.boardState = e.Data
		close(conn.tick)
		session.lock.Unlock()

		for _, ch := range []chan struct{}{
			session.conn1.tick,
			session.conn2.tick,
		} {
			select {
			case <-ch:
			case <-session.closed:
			}
		}

		session.lock.RLock()
		defer session.lock.RUnlock()
		s.Emit("draw")
		conn.tick = make(chan struct{})
		s.Emit("draw-otherboard", oponentConn.boardState)
	})

	lis, err := net.Listen("tcp", "0.0.0.0:8001")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	appMux := http.NewServeMux()
	svc := &http.Server{
		Handler: appMux,
	}
	appMux.HandleFunc("/register-game", func(w http.ResponseWriter, r *http.Request) {
		type users struct {
			Users []string
		}
		var u users
		if err := json.NewDecoder(r.Body).Decode(&u); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		log.Printf("register-game: %s\n", u)
		sessionID := uuid.New().String()

		lock.Lock()
		defer lock.Unlock()
		activeSessions[sessionID] = &session{
			seed:   rand.Uint64(),
			closed: make(chan struct{}),
			conn1: &connection{
				user:   u.Users[0],
				socket: nil,
				ready:  make(chan struct{}),
				tick:   make(chan struct{}),
			},
			conn2: &connection{
				user:   u.Users[1],
				socket: nil,
				ready:  make(chan struct{}),
				tick:   make(chan struct{}),
			},
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]any{
			"session-id": sessionID,
			"redirect-urls": map[string]string{
				u.Users[0]: fmt.Sprintf(gameHost+"/tetris/index.html?session-id=%s&user=%s&opponent=%s", sessionID, u.Users[0], u.Users[1]),
				u.Users[1]: fmt.Sprintf(gameHost+"/tetris/index.html?session-id=%s&user=%s&opponent=%s", sessionID, u.Users[1], u.Users[0]),
			},
		})
	})

	log.Println("Starting app server on port :8001")
	go func() {
		if err := svc.Serve(lis); err != nil {
			log.Fatalf("server error: %v", err)
		}
	}()
	defer svc.Close()

	tmpl := template.Must(template.ParseFS(tmplContent, "index.html.tmpl"))

	type data struct {
		SessionID string
		User      string
		Opponent  string
		GameHost  string
		LobbyHost string
	}

	mux := http.NewServeMux()

	mux.Handle("/game/socket.io/", server)

	mux.HandleFunc("/tetris/index.html", func(w http.ResponseWriter, r *http.Request) {
		tmpl.Execute(w, &data{
			SessionID: r.URL.Query().Get("session-id"),
			User:      r.URL.Query().Get("user"),
			Opponent:  r.URL.Query().Get("opponent"),
			GameHost:  gameHost,
			LobbyHost: lobbyHost,
		})
	})

	tetrisFS, err := fs.Sub(content, "assets")
	if err != nil {
		log.Fatal(err)
	}
	mux.Handle("/tetris/", http.StripPrefix("/tetris", http.FileServer(http.FS(tetrisFS))))
	mux.Handle("/", http.RedirectHandler("/index.html", http.StatusPermanentRedirect))
	srv := http.Server{
		Addr:    ":8000",
		Handler: mux,
	}
	go server.Serve()
	defer server.Close()
	log.Println("Game listening at :8000...")
	log.Fatal(srv.ListenAndServe())
}
