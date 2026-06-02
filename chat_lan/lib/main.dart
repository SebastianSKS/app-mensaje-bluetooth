import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const ChatLanApp());
}

// Paleta de colores estilo Discord / Premium
const Color fondoOscuro = Color(0xFF36393F);
const Color fondoPaneles = Color(0xFF2F3136);
const Color colorPrimario = Color(0xFF5865F2);
const Color fondoInput = Color(0xFF202225);

class ChatLanApp extends StatelessWidget {
  const ChatLanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat de Amigos',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: fondoOscuro,
        appBarTheme: const AppBarTheme(
          backgroundColor: fondoPaneles,
          elevation: 2,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorPrimario,
            foregroundColor: Colors.white,
            elevation: 5,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const PantallaInicio(),
    );
  }
}

// ==========================================
// PANTALLA DE INICIO (MENÚ PRINCIPAL)
// ==========================================

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Punto de Reunión')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícono de chat amigable (Cero IAs)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: fondoPaneles,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  size: 80,
                  color: colorPrimario,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                '¿Cómo nos conectamos?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PantallaHost(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.wifi_tethering, size: 28),
                  label: const Text(
                    'Abrir Sala (Invitar)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PantallaCliente(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.login, size: 28),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: fondoPaneles,
                    foregroundColor: Colors.white,
                  ),
                  label: const Text(
                    'Entrar a una Sala',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA DEL HOST
// ==========================================

class PantallaHost extends StatefulWidget {
  const PantallaHost({super.key});

  @override
  State<PantallaHost> createState() => _PantallaHostState();
}

class _PantallaHostState extends State<PantallaHost> {
  ServerSocket? _serverSocket;
  String _ipLocal = "";
  List<String> _mensajes = [];
  List<Socket> _clientesConectados = [];

  @override
  void initState() {
    super.initState();
    _iniciarServidor();
  }

  Future<void> _iniciarServidor() async {
    try {
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

      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 8080);

      _serverSocket!.listen((Socket cliente) {
        setState(() {
          _clientesConectados.add(cliente);
          _mensajes.add("👋 Alguien acaba de entrar a la sala");
        });

        cliente.listen(
          (List<int> data) {
            String mensajeRecibido = String.fromCharCodes(data);
            setState(() {
              _mensajes.add(mensajeRecibido);
            });

            for (var c in _clientesConectados) {
              if (c != cliente) {
                c.write(mensajeRecibido);
              }
            }
          },
          onDone: () {
            setState(() {
              _clientesConectados.remove(cliente);
              _mensajes.add("🚪 Alguien salió de la sala.");
            });
          },
        );
      });
    } catch (e) {
      setState(() {
        _mensajes.add("Error: $e");
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
      appBar: AppBar(title: const Text('Sala de Espera')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: fondoPaneles,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Que tus amigos escaneen este código:',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                if (_ipLocal.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: _ipLocal,
                      version: QrVersions.auto,
                      size: 160.0,
                    ),
                  )
                else
                  const CircularProgressIndicator(color: colorPrimario),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'IP: $_ipLocal : 8080',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: fondoPaneles,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _mensajes.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      _mensajes[index],
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PANTALLA DEL CLIENTE
// ==========================================

class PantallaCliente extends StatefulWidget {
  const PantallaCliente({super.key});

  @override
  State<PantallaCliente> createState() => _PantallaClienteState();
}

class _PantallaClienteState extends State<PantallaCliente> {
  Socket? _socket;
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _mensajeController = TextEditingController();

  List<String> _mensajes = [];
  bool _conectado = false;

  void _conectarAlHost() async {
    try {
      _socket = await Socket.connect(_ipController.text, 8080);
      setState(() {
        _conectado = true;
        _mensajes.add("✅ Ya estás adentro del chat.");
      });

      _socket!.listen(
        (List<int> data) {
          setState(() {
            _mensajes.add(String.fromCharCodes(data));
          });
        },
        onDone: () {
          setState(() {
            _conectado = false;
            _mensajes.add("❌ Se cortó la conexión.");
          });
          _socket?.destroy();
        },
      );
    } catch (e) {
      setState(() {
        _mensajes.add("No se pudo conectar. Revisa el código o la IP.");
      });
    }
  }

  void _enviarMensaje() {
    if (_mensajeController.text.isNotEmpty && _socket != null) {
      String nombre = _nombreController.text.isEmpty
          ? "Amigo"
          : _nombreController.text;
      String mensaje = "$nombre: ${_mensajeController.text}";

      _socket!.write(mensaje);

      setState(() {
        _mensajes.add("Tú: ${_mensajeController.text}");
        _mensajeController.clear();
      });
    }
  }

  Future<void> _abrirEscaner() async {
    final ipEscaneada = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PantallaEscanerQR()),
    );

    if (ipEscaneada != null) {
      setState(() {
        _ipController.text = ipEscaneada;
      });
      _conectarAlHost();
    }
  }

  @override
  void dispose() {
    _socket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sala de Chat')),
      body: Column(
        children: [
          if (!_conectado)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: fondoPaneles,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          size: 60,
                          color: colorPrimario,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Reúnete con el grupo',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 25),
                        _crearCampoDeTexto(
                          _nombreController,
                          'Tu nombre...',
                          Icons.person,
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _abrirEscaner,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text(
                              'Escanear QR',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            "O ingresa la IP a mano",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        _crearCampoDeTexto(
                          _ipController,
                          'IP Ej. 192.168.1.5',
                          Icons.numbers,
                          esNumero: true,
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _conectarAlHost,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white12,
                            ),
                            child: const Text('Conectar manual'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_conectado) ...[
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _mensajes.length,
                itemBuilder: (context, index) {
                  bool soyYo = _mensajes[index].startsWith("Tú:");
                  bool esSistema =
                      _mensajes[index].startsWith("✅") ||
                      _mensajes[index].startsWith("❌");

                  if (esSistema) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          _mensajes[index],
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    alignment: soyYo
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: soyYo ? colorPrimario : fondoPaneles,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: soyYo
                              ? const Radius.circular(20)
                              : Radius.zero,
                          bottomRight: soyYo
                              ? Radius.zero
                              : const Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        _mensajes[index],
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              color: fondoPaneles,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mensajeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: fondoInput,
                        hintText: 'Escribe un mensaje...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: colorPrimario,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _enviarMensaje,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _crearCampoDeTexto(
    TextEditingController controller,
    String hint,
    IconData icono, {
    bool esNumero = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: esNumero ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: fondoInput,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icono, color: Colors.white54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA DEL ESCÁNER QR
// ==========================================

class PantallaEscanerQR extends StatelessWidget {
  const PantallaEscanerQR({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enfoca el QR del Host')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: colorPrimario, width: 4),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const Positioned(
            bottom: 50,
            child: Text(
              'Apunta la cámara hacia la pantalla de tu amigo',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
