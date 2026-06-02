import 'dart:io';
import 'package:flutter/material.dart';

void main() {
  runApp(const ChatLanApp());
}

class ChatLanApp extends StatelessWidget {
  const ChatLanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat LAN',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const PantallaInicio(),
    );
  }
}

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat Secreto LAN'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                // Navegamos a la pantalla del Host
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PantallaHost()),
                );
              },
              icon: const Icon(Icons.wifi_tethering),
              label: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Crear Sala (Ser Host)',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                // Todavía no hacemos esta pantalla, por ahora solo imprime en consola
                print("Próximamente: Pantalla para unirse");
              },
              icon: const Icon(Icons.login),
              label: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Unirse a Sala (Cliente)',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA DEL HOST (EL SERVIDOR LOCAL)
// ==========================================

class PantallaHost extends StatefulWidget {
  const PantallaHost({super.key});

  @override
  State<PantallaHost> createState() => _PantallaHostState();
}

class _PantallaHostState extends State<PantallaHost> {
  ServerSocket? _serverSocket;
  String _ipLocal = "Buscando IP...";
  List<String> _mensajes = [];
  List<Socket> _clientesConectados = [];

  @override
  void initState() {
    super.initState();
    _iniciarServidor();
  }

  Future<void> _iniciarServidor() async {
    try {
      // 1. Buscar la IP local del dispositivo
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            setState(() {
              _ipLocal = addr.address;
            });
            break;
          }
        }
      }

      // 2. Levantar el servidor en el puerto 8080
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 8080);

      // 3. Quedarse escuchando a ver si alguien se conecta
      _serverSocket!.listen((Socket cliente) {
        setState(() {
          _clientesConectados.add(cliente);
          _mensajes.add("¡Alguien se ha conectado!");
        });

        // 4. Escuchar los mensajes que manda ese cliente
        cliente.listen(
          (List<int> data) {
            String mensajeRecibido = String.fromCharCodes(data);
            setState(() {
              _mensajes.add("Amigo: $mensajeRecibido");
            });

            // Retransmitir el mensaje a los demás conectados
            for (var c in _clientesConectados) {
              if (c != cliente) {
                c.write(mensajeRecibido);
              }
            }
          },
          onDone: () {
            setState(() {
              _clientesConectados.remove(cliente);
              _mensajes.add("Alguien se desconectó.");
            });
          },
        );
      });
    } catch (e) {
      setState(() {
        _ipLocal = "Error al iniciar servidor";
        _mensajes.add(e.toString());
      });
    }
  }

  @override
  void dispose() {
    _serverSocket?.close();
    for (var cliente in _clientesConectados) {
      cliente.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sala del Host'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade100,
            width: double.infinity,
            child: Column(
              children: [
                const Text(
                  'Pide a tus amigos que se conecten a esta IP:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _ipLocal,
                  style: const TextStyle(fontSize: 32, color: Colors.green),
                ),
                const Text('Puerto: 8080', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _mensajes.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_mensajes[index]),
                  leading: const Icon(Icons.message, color: Colors.green),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
