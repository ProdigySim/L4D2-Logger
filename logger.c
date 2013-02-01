#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sqlite3.h>

#define PORT "55555"
#define MAXBUFLEN 512

void protocol3(char *cursor, char *query, int len);

int main(int argc, const char *argv[])
{
	struct addrinfo hints, *res;
	struct sockaddr_storage recv_addr;
	char buf[MAXBUFLEN];
	int sockfd, recv_addr_len;
	char *cursor;

	int protocol;

	sqlite3 *db;
	int rc;
	char query[256];
	sqlite3_stmt *ppStmt;

	if (argc != 2)
	{
		fprintf(stderr, "Usage: %s database\n", argv[0]);
		exit(1);
	}
	
	rc = sqlite3_open(argv[1], &db);
	if (rc)
	{
		fprintf(stderr, "Can't open database: %s\n", sqlite3_errmsg(db));
		sqlite3_close(db);
		exit(1);
	}

	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_DGRAM;
	hints.ai_flags = AI_PASSIVE;

	getaddrinfo(NULL, PORT, &hints, &res);

	sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);

	bind(sockfd, res->ai_addr, res->ai_addrlen);

	for (;;)
	{
		memset(buf, 0, sizeof(buf));
		cursor = buf;
		recvfrom(sockfd, buf, MAXBUFLEN-1, 0, (struct sockaddr *)&recv_addr,
				&recv_addr_len);

		memcpy(&protocol, cursor, sizeof(int));
		cursor += sizeof(protocol);

		switch (protocol)
		{
			case (3):
				protocol3(cursor, query, sizeof(query));
				break;
			default:
				query[0] = '\0';
		}

		sqlite3_prepare_v2(db, query, sizeof(query), &ppStmt, NULL);
		sqlite3_step(ppStmt);
		sqlite3_finalize(ppStmt);
	}

	sqlite3_close(db);
	freeaddrinfo(res);
	close(sockfd);
	exit(0);
}

void protocol3(char *cursor, char *query, int len)
{
	char configname[32], mapname[32];
	int alivesurvs, survcompletion[4], survhealth[4], bossflow[2];

	strcpy(configname, cursor);
	cursor += sizeof(char) + strlen(cursor);
	strcpy(mapname, cursor);
	cursor += sizeof(char) + strlen(cursor);
	memcpy(&alivesurvs, cursor, sizeof(alivesurvs));
	cursor += sizeof(alivesurvs);
	memcpy(survcompletion, cursor, 4*sizeof(survcompletion));
	cursor += 4*sizeof(survcompletion);
	memcpy(survhealth, cursor, 4*sizeof(survhealth));
	cursor += 4*sizeof(survhealth);
	memcpy(bossflow, cursor, 4*sizeof(bossflow));
	cursor += 4*sizeof(bossflow);

	snprintf(query, len, "INSERT INTO log VALUES(\"%s\", \"%s\", %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d);", configname, mapname, alivesurvs, survcompletion[0], survcompletion[1], survcompletion[2], survcompletion[3], survhealth[0], survhealth[1], survhealth[2], survhealth[3], bossflow[0], bossflow[1]);
}
