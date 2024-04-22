sudo apt-get update
sudo apt-get install -y xdg-utils
curl -o- https://downloads.diagrid.io/cli/install-catalyst.sh | bash
sudo mv ./diagrid /usr/local/bin
diagrid update --approve
