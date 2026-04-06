# Networking & Server Architecture

## Server Applications

### authserver (src/server/apps/authserver/)
- **Port:** 3724
- **Protocol:** Custom SRP6 authentication
- **Flow:** Client -> AuthSession -> Account verification -> Realm list -> Redirect to worldserver
- **Key files:** Main.cpp, AuthSession.cpp, AuthCodes.cpp

### worldserver (src/server/apps/worldserver/)
- **Port:** 8085 (game), 7878 (SOAP)
- **Protocol:** Custom binary packet protocol over TCP
- **Key files:** Main.cpp, ACSoap/, CommandLine/CliRunnable, RemoteAccess/RASession

## Network Stack

### Shared Layer (src/server/shared/Network/)
- AsyncAcceptor.h - Boost.Asio TCP acceptor
- NetworkThread.h - Per-thread socket management
- Socket.h - Base socket with read/write buffers
- SocketMgr.h - Socket lifecycle management

### Packet System

#### ByteBuffer (src/server/shared/Packets/)
Binary serialization for all network data. Supports << and >> operators for all game types.

#### WorldPacket (src/server/game/Server/)
Extends ByteBuffer with opcode header. Each packet type has a uint16 opcode.

#### Opcodes (src/server/game/Server/Protocol/)
- Opcodes.h/.cpp - Full opcode enum and handler table
- ~1200+ opcodes (CMSG_* = client->server, SMSG_* = server->client)

### Session Management

#### WorldSession (src/server/game/Server/)
- One per connected player
- Receives WorldPackets, dispatches to Handler methods
- Owns Player* reference
- Handles authentication handshake after auth redirect
- ~34 handler files in src/server/game/Handlers/

#### WorldSocket
- Inherits from shared Socket
- Handles encryption (ARC4 after auth)
- Packet assembly and disassembly

#### WorldSocketMgr
- Manages all active WorldSockets
- Thread pool for network I/O

## World Singleton (src/server/game/World/)
- Global game state
- Update loop (~50ms tick)
- Configuration management
- Session management
- Shutdown/restart handling

## Packet Flow
```
Client
  ↓ TCP
WorldSocket (decrypt, deserialize)
  ↓ WorldPacket
WorldSession (opcode lookup)
  ↓ dispatch
Handler method (e.g., HandleMovementOpcodes)
  ↓ game logic
Unit/Player/Map updates
  ↓ response
WorldPacket (serialize)
  ↓
WorldSocket (encrypt, send)
  ↓ TCP
Client
```

## SOAP Interface (src/server/apps/worldserver/ACSoap/)
- HTTP-based remote administration
- Port 7878
- Execute GM commands remotely
- Used by web panels and tools
