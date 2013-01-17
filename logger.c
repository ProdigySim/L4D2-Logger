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

#define PORT "55555"
#define MAXBUFLEN 100

int
main (void)
{
	struct addrinfo hints, *res;
	struct sockaddr_storage recv_addr;
	char buf[MAXBUFLEN];
	int sockfd, recv_addr_len;

	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_DGRAM;
	hints.ai_flags = AI_PASSIVE;

	getaddrinfo(NULL, PORT, &hints, &res);

	sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);

	bind(sockfd, res->ai_addr, res->ai_addrlen);

	for (;;)
	{
		recvfrom(sockfd, buf, MAXBUFLEN-1, 0, (struct sockaddr *)&recv_addr, &recv_addr_len);

		printf("%s\n", buf);
		memset(buf, 0, sizeof(buf));
	}

	freeaddrinfo(res);
	close(sockfd);
	return 0;
}
