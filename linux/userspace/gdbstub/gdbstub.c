#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <err.h>

#define GDBSTUB_PORT		1234
#define GDBSTUB_PACKET_SIZE	1024

struct gdbstub_registers {
	uint32_t reg[16];
};

static struct gdbstub_registers regs = {
	.reg = {
		0x11111111, 0x22222222, 0x33333333, 0x44444444,
		0x55555555, 0x66666666, 0x77777777, 0x88888888,
		0x99999999, 0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC,
		0xDDDDDDDD, 0xEEEEEEEE, 0xFFFFFFFF, 0x12345678
	}
};

static uint8_t gdbstub_checksum(const char *buf, int len)
{
	uint8_t csum = 0;
	for (int i = 0; i < len; ++i)
		csum += (uint8_t) buf[i];
	return csum;
}

static int gdbstub_hex_to_int(char c)
{
	if (c >= '0' && c <= '9') return c - '0';
	if (c >= 'a' && c <= 'f') return c - 'a' + 10;
	if (c >= 'A' && c <= 'F') return c - 'A' + 10;
	return -1;
}

static char gdbstub_int_to_hex_char(int n)
{
	return (n < 10)
		? '0' + n
		: 'a' + (n - 10);
}

static void gdbstub_packet_send(int fd, const char *buf)
{
	uint8_t csum = gdbstub_checksum(buf, strlen(buf));
	char packet[GDBSTUB_PACKET_SIZE] = {0};
	ssize_t n = snprintf(packet, sizeof (packet), "$%s#%02x", buf, csum);
	
	if (write(fd, packet, n) < 0)
		err(-1, "write()");
}

static char *gdbstub_packet_read(int fd, char *buf, size_t size)
{
	int i = 0;
	char c = '\0';

	do {
		ssize_t r = read(fd, &c, 1);
		if (r <= 0)
			return NULL;
	} while (c != '$');

	while (i < size - 1) {
		ssize_t r = read(fd, &c, 1);
		if (r <= 0)
			return NULL;

		if (c == '#')
			break;

		buf[i++] = c;
	}

	buf[i] = '\0';

	if (c != '#')
		return NULL;

	char csum1 = '\0';
	char csum2 = '\0';

	if (read(fd, &csum1, 1) < 0)
		return NULL;

	if (read(fd, &csum2, 1) < 0)
		return NULL;

	int recv_csum = gdbstub_hex_to_int(csum1) << 4
	              | gdbstub_hex_to_int(csum2);
	uint8_t calc_csum = gdbstub_checksum(buf, i);

	if (recv_csum == calc_csum) {
		write(fd, "+", 1);
		return buf;
	} else {
		write(fd, "-", 1);
		return NULL;
	}
}

static void gdbstub_encode_reg(char *out, uint32_t reg)
{
	for (int i = 0; i < 4; ++i) {
		uint8_t b = (reg >> (i * 8)) & 0xFF;
		out[i * 2 + 0] = gdbstub_int_to_hex_char((b >> 4) & 0xF);
		out[i * 2 + 1] = gdbstub_int_to_hex_char(b & 0xF);
	}
}

static void gdbstub_handle_cmd(int fd, const char *cmd)
{
	switch (cmd[0]) {
	case '?':
		gdbstub_packet_send(fd, "S05");
		break;
	case 'g': {
		char reg[16 * 8 + 1] = {0};
		char *p = reg;

		for (int i = 0; i < 16; ++i) {
			gdbstub_encode_reg(p, regs.reg[i]);
			p += 8;
		}
		*p = '\0';
		gdbstub_packet_send(fd, reg);
		break;
	}
	case 'q':
		gdbstub_packet_send(fd, "");
		break;
	case 'c':
	case 's':
		gdbstub_packet_send(fd, "S05");
		break;
	default:
		gdbstub_packet_send(fd, "");
		break;
	}
}

int main()
{
	int server_fd = socket(AF_INET, SOCK_STREAM, 0);
	if (server_fd < 0)
		err(-1, "socket()");

	int opt = 1;
	setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof (opt));

	struct sockaddr_in addr = {
		.sin_family	= AF_INET,
		.sin_addr = {
			.s_addr	= INADDR_ANY
		},
		.sin_port	= htons(GDBSTUB_PORT)
	};

	if (bind(server_fd, (struct sockaddr *) &addr, sizeof (addr)) < 0)
		err(-1, "bind()");

	if (listen(server_fd, 1) < 0)
		err(-1, "listen()");

	printf("GDB stub: listening on port %d\n", GDBSTUB_PORT);

	socklen_t addrlen = sizeof (addr);
	int client_fd = accept(server_fd, (struct sockaddr *) &addr, &addrlen);
	if (client_fd < 0)
		err(-1, "accept()");

	printf("GDB stub: connected\n");

	char packet_buf[GDBSTUB_PACKET_SIZE] = {0};

	while (1) {
		char *packet = gdbstub_packet_read(client_fd, packet_buf, sizeof (packet_buf));
		if (packet == NULL) {
			printf("NULL packet\n");
			break;
		}

		printf("GDB stub: command `%s`\n", packet);
		gdbstub_handle_cmd(client_fd, packet);
	}

	close(client_fd);
	close(server_fd);
}
