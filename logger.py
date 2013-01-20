#!/usr/bin/python

import socket
import sys
import sqlite3

address = ('localhost', 55555)

if len(sys.argv) != 2:
	print("Usage: logger.py /path/to/sqlite3/db")
	sys.exit()

db = sqlite3.connect(sys.argv[1])
c = db.cursor()

serversocket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
serversocket.bind(address)

while 1:
	data = serversocket.recv(128).decode('utf-8')
	tokens = data.split(',')
	c.execute('INSERT INTO log VALUES (?, ?, ?)', tokens)
	db.commit()
	print(tokens)
