#!/usr/bin/env python

import os
import grpc
import logging
import redis
import json
import threading
from flask import Flask, render_template, request, jsonify, flash, session, redirect, url_for
from flask_socketio import SocketIO
from dapr.clients import DaprClient
from werkzeug.security import generate_password_hash, check_password_hash
from cloudevents.http import from_http
from http.server import BaseHTTPRequestHandler, HTTPServer, ThreadingHTTPServer
from names_generator import generate_name

app = Flask(__name__)
app.secret_key = os.environ.get('FLASK_KEY')
logging.basicConfig(level=logging.INFO)
socketio = SocketIO(app)

waiting_list_store_name = 'kvstore'
#user_store_name = 'userscores'
user_store_name = 'kvstore'
socket_sessions = dict()

leaderboardQuery = '''
{
 "filter": {
  "EQ": { "type": "user" }
 },
 "sort": [
  {
   "key": "wins",
   "order": "DESC"
  }
 ],
 "page": {
  "limit": 20
 }
}
'''

class AppHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        app.logger.info("Got POST request for "+self.path)
        if self.path != "/update-score":
            self.send_response(404)
            self.end_headers()
            return
        data = self.rfile.read(int(self.headers['Content-Length']))
        jdata = json.loads(data.decode("utf-8"))
        app.logger.info("Got update-score request for "+str(jdata))
        self.send_header("Content-type", "application/json")
        self.send_response(200)
        self.end_headers()
        self.wfile.write(json.dumps({"success": True}).encode("utf-8"))
        for player in jdata["data"]:
            if player["User"] and player["Winner"] and player["Score"]:
                Player(player["User"]).update_score(player["Winner"], player["Score"])

daprdserver = ThreadingHTTPServer(("0.0.0.0", 8002), AppHandler)
daprdserver_thread = threading.Thread(target=daprdserver.serve_forever)
daprdserver_thread.daemon = True

@app.route('/')
def home():
    if 'username' not in session:
        return redirect(url_for('login_page'))

    wins, points, games = 0, 0, 0
    scores_list = []

    # Get player score
    with DaprClient() as dapr_client:
        app.logger.info("Getting score for >"+session["username"]+"<")
        try:
            resp = dapr_client.get_state(store_name=user_store_name, key=session["username"], state_metadata={"contentType": "application/json"})
            if resp.data:
                score = json.loads(resp.data.decode("utf-8"))
                wins, points, games = score["wins"], score["points"], score["games"]
            try:
                leaderboard = dapr_client.query_state(store_name=user_store_name,
                                                  query=leaderboardQuery,
                                                  states_metadata={"queryIndexName": "leaderboardIndex","contentType": "application/json"})
                for r in leaderboard.results:
                    d = json.loads(r.value.decode("utf-8"))
                    scores_list.append((r.key, {'wins': d["wins"], 'points': d["points"], 'games': d['games']}))
            except grpc.RpcError as error:
                app.logger.error('failed to get leaderboard: {0}'.format(error))
        except grpc.RpcError as error:
            session.pop('username', None)
            return redirect(url_for('login_page'))

    return render_template('index.html', username=session["username"], wins=wins, points=points, games=games, scores=scores_list)

@app.route('/signup', methods=["GET"])
def signup_page():
    user = generate_name(style='capital')
    user = user.replace(" ", "")
    return render_template('signup.html', username=user)

@app.route('/signup', methods=["POST"])
def signup():
    username = request.form['username']
    password = request.form['password']

    with DaprClient() as dapr_client:
        # Check if user already exists and create it if it doesn't
        try:
            user = dapr_client.get_state(store_name=user_store_name, key=username, state_metadata={"contentType": "application/json"})
            if user.data:
                flash("User already exists", "error")
                return render_template('signup.html')
        except grpc.RpcError as error:
            app.logger.error('Signup for user which doesn\'t exist')

        app.logger.info("Creating user "+username)
        psswd = generate_password_hash(password, )
        dapr_client.save_state(store_name=user_store_name, key=username,
                               value=json.dumps({"wins": 0, "points": 0, "games": 0, "password": psswd, "type": "user"}),
                               state_metadata={"contentType": "application/json"})

        app.logger.info("Created user "+username)

        # Automatically log in / create session
        session['username'] = username

        # Redirect to home
        return redirect(url_for('home'))

@app.route('/login', methods=["GET"])
def login_page():
    if 'username' in session:
        return redirect(url_for('home'))

    return render_template('login.html')


@app.route('/login', methods=["POST"])
def login():
    username = request.form['username']
    password = request.form['password']

    with DaprClient() as dapr_client:
        # Check if user already exists
        try:
            user = dapr_client.get_state(store_name=user_store_name, key=username, state_metadata={"contentType": "application/json"})

            if not user.data:
                flash("User doesn't exist", "error")
                return redirect(url_for('login_page'))

            # Check if the password is correct
            data = json.loads(user.data.decode("utf-8"))
            if not check_password_hash(data["password"], password):
                flash("Incorrect password", "error")
                return redirect(url_for('login_page'))

            # Create session
            session['username'] = username

            # Redirect to home
            return redirect(url_for('home'))

        except grpc.RpcError as error:
            flash("User doesn't exist", "error")
            return redirect(url_for('login_page'))

@app.route('/logout', methods=["GET"])
def logout():
    session.pop('username', None)
    return redirect(url_for('login_page'))

@socketio.on('start_game')
def socket_start_game():
    app.logger.info("Starting game "+session["username"])

    if 'username' not in session:
        socketio.emit('redirect_game', url_for('login_page'), room=request.sid)
        return

    svc = GameService()
    player2 = svc.match_player(session["username"])
    if not player2:
        socketio.emit('waiting', room=request.sid)
        return

    regJSON = svc.register_game(player2)
    reg = json.loads(regJSON.data.decode("utf-8"))
    for username, sid in socket_sessions.items():
        if username == session["username"]:
            socketio.emit('redirect_game', 'http://'+reg["redirect-urls"][session["username"]], room=sid)
            socketio.emit('redirect_game', 'http://'+reg["redirect-urls"][player2])
            return

    socketio.emit('waiting', room=socket_sessions[player2])
    return

#Create a python function that uses get_state of a key named leaderboard. The result is an array of objects that contains the player name, wins, games and points. The array should be sorted by wins in descending order.
def get_sorted_leaderboard():
    with DaprClient() as dapr_client:
        leaderboard_state = dapr_client.get_state(store_name=user_store_name, key='leaderboard')
        leaderboard = json.loads(leaderboard_state.data.decode('utf-8'))
        sorted_leaderboard = sorted(leaderboard, key=lambda player: player['wins'], reverse=True)
        return sorted_leaderboard

@socketio.on('connect')
def socket_connect():
    if 'username' not in session:
        return
    socket_sessions.update({session["username"]: request.sid})

@socketio.on('disconnect')
def socket_disconnect():
    socket_sessions.pop(session["username"])
    with DaprClient() as dapr_client:
        waiting_list = dapr_client.get_state(store_name=waiting_list_store_name, key='waiting_list')
        if waiting_list.data.decode("utf-8") == session["username"]:
            dapr_client.save_state(store_name=waiting_list_store_name, key='waiting_list', value="",
                                   etag=waiting_list.etag)

class GameService():
    def match_player(self, player1):
        app.logger.info("Matching player " + player1)

        with DaprClient() as dapr_client:
            # Check if there are players waiting in the queue
            waiting_list = dapr_client.get_state(store_name=waiting_list_store_name, key='waiting_list')

            # If no one's waiting, add player1 to the waiting list and show a message to the user
            if not waiting_list.daprdserver_thread:
                try:
                    # Add player 1 to the waiting list
                    dapr_client.save_state(store_name=waiting_list_store_name, key='waiting_list',
                                           value=session["username"], etag=waiting_list.etag)
                except grpc.RpcError as error:
                    # Someone else added another player to waiting list in the meantime. Try again!
                    app.logger.error(error)
                    self.match_player(player1)

                return None

            player2 = waiting_list.data.decode("utf-8")
            try:
                # Try to remove a player from the waiting list
                dapr_client.save_state(store_name=waiting_list_store_name, key='waiting_list', value="",
                                       etag=waiting_list.etag)
            except grpc.RpcError as error:
                app.logger.error('failed to remove player from waiting list: {0}'.format(error))
                # Someone else has already removed the player from the waiting list. Try again.
                self.match_player(player1)
                return None

            if player2 == player1:
                # We can't play with ourselves. Try again.
                self.match_player(player1)
                return None

            return player2

    def register_game(self, player2):
        # Create a new game session
        with DaprClient() as dapr_client:
            registered = dapr_client.invoke_method(app_id='game',
                                                        method_name='register-game',
                                                        data=json.dumps({'users': [session['username'], player2]}))
            return registered

    def __str__(self):
        return "Player 1: {}, Player 2: {}".format(self.player1, self.player2)


class Player():
    def __init__(self, username: str):
        self.username = username

    def update_score(self, winner: bool, upoints: int):
        # Update the player's score'
        with DaprClient() as dapr_client:
            # Get current score
            app.logger.info("Updating score for "+self.username)
            resp = dapr_client.get_state(store_name=user_store_name, key=self.username, state_metadata={"contentType": "application/json"})

            data = json.loads(resp.data.decode("utf-8"))
            app.logger.info(data)
            password = data["password"]
            wins = data["wins"]
            if winner:
                wins += 1
            points = data["points"] + upoints;
            games = data["games"] + 1;

            try:
                dapr_client.save_state(store_name=user_store_name,
                                       key=self.username,
                                       value=json.dumps({"wins": wins, "points": points, "games": games, "password": password, "type": "user"}),
                                       state_metadata={"contentType": "application/json"},
                                       etag=resp.etag)
            except grpc.RpcError as error:
                # Someone else added a score in the meantime. Try again!
                self.update_score(winner, upoints)

    def __str__(self):
        return "Username: {}, Wins: {}, Points: {}, Games: {}".format(self.username, self.wins, self.points, self.games)

with app.app_context():
    app.logger.info("Starting app server on port 8002")
    daprdserver_thread.start()

if __name__ == '__main__':
    socketio.run(app, allow_unsafe_werkzeug=True, host='0.0.0.0')
