import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ChatLanApp());
}

const Color fondoOscuro = Color(0xFF0B141A);
const Color fondoAppbar = Color(0xFF1F2C34);
const Color burbujaMia = Color(0xFF005C4B);
const Color burbujaOtro = Color(0xFF202C33);
const Color colorAcento = Color(0xFF00A884);

// Generador de colores únicos para los nombres de usuario
Color _getColorPorNombre(String nombre) {
  const colores = [
    Color(0xFFEF9A9A),
    Color(0xFFCE93D8),
    Color(0xFF90CAF9),
    Color(0xFF80CBC4),
    Color(0xFFA5D6A7),
    Color(0xFFFFCC80),
    Color(0xFFFFAB91),
    Color(0xFF81D4FA),
    Color(0xFFB39DDB),
  ];
  return colores[nombre.hashCode.abs() % colores.length];
}

class ChatLanApp extends StatelessWidget {
  const ChatLanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WhatsApp LAN',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: fondoOscuro,
        appBarTheme: const AppBarTheme(
          backgroundColor: fondoAppbar,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorAcento,
            foregroundColor: fondoOscuro,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
      home: const PantallaInicio(),
    );
  }
}

// ==========================================
// ESTRUCTURA DEL MENSAJE (MEJORADA)
// ==========================================
class MensajeChat {
  final String nombre; // Nuevo campo para el color
  final String texto;
  final bool soyYo;
  final bool esSistema;
  final String hora;

  MensajeChat({
    this.nombre = "",
    required this.texto,
    required this.soyYo,
    required this.esSistema,
    required this.hora,
  });

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'texto': texto,
    'soyYo': soyYo,
    'esSistema': esSistema,
    'hora': hora,
  };

  factory MensajeChat.fromJson(Map<String, dynamic> json) => MensajeChat(
    nombre: json['nombre'] ?? "",
    texto: json['texto'] ?? "",
    soyYo: json['soyYo'] ?? false,
    esSistema: json['esSistema'] ?? false,
    hora: json['hora'] ?? "",
  );
}

String _obtenerHoraActual() {
  final ahora = DateTime.now();
  final hora = ahora.hour.toString().padLeft(2, '0');
  final minuto = ahora.minute.toString().padLeft(2, '0');
  return "$hora:$minuto";
}

// ==========================================
// PANTALLA DE INICIO
// ==========================================

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats LAN')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: colorAcento,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.forum, size: 80, color: fondoOscuro),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PantallaHost(),
                    ),
                  ),
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text(
                    'Crear Grupo (Ser Host)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PantallaCliente(),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_scanner),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: fondoAppbar,
                    foregroundColor: Colors.white,
                  ),
                  label: const Text(
                    'Escanear y Unirse',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
  List<Socket> _clientesConectados = [];
  List<MensajeChat> _mensajes = [];

  final TextEditingController _mensajeController = TextEditingController();
  final TextEditingController _nombreController =
      TextEditingController(); // Ya no dice Fidel quemado
  final ScrollController _scrollController = ScrollController();

  String _quienEscribe = "";
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _iniciarServidor();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    // Cargar nombre guardado
    _nombreController.text = prefs.getString('mi_nombre_host') ?? "Host";

    // Cargar historial
    final String? historialJson = prefs.getString('historial_host');
    if (historialJson != null) {
      final List<dynamic> decodificado = jsonDecode(historialJson);
      setState(() {
        _mensajes = decodificado
            .map((item) => MensajeChat.fromJson(item))
            .toList();
      });
      _hacerScrollHaciaAbajo();
    }
  }

  Future<void> _guardarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('mi_nombre_host', _nombreController.text);
    final String historialJson = jsonEncode(
      _mensajes.map((m) => m.toJson()).toList(),
    );
    prefs.setString('historial_host', historialJson);
  }

  void _hacerScrollHaciaAbajo() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _mostrarEscribiendo(String nombre) {
    setState(() {
      _quienEscribe = "$nombre está escribiendo...";
    });
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted)
        setState(() {
          _quienEscribe = "";
        });
    });
  }

  Future<void> _iniciarServidor() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            if (!mounted) return;
            setState(() {
              _ipLocal = addr.address;
            });
            break;
          }
        }
      }

      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 8080);

      _serverSocket!.listen((Socket cliente) {
        if (!mounted) return;
        setState(() {
          _clientesConectados.add(cliente);
          _mensajes.add(
            MensajeChat(
              texto: "Alguien se unió al grupo",
              soyYo: false,
              esSistema: true,
              hora: _obtenerHoraActual(),
            ),
          );
        });
        _guardarHistorial();
        _hacerScrollHaciaAbajo();

        cliente.listen(
          (List<int> data) {
            if (!mounted) return;
            String stringData = String.fromCharCodes(data);

            // Separar comandos en caso de que lleguen pegados por la red
            List<String> comandos = stringData.split("CMD::");
            for (String cmd in comandos) {
              if (cmd.isEmpty) continue;

              if (cmd.startsWith("TYPING::")) {
                String nombreAmigo = cmd.replaceAll("TYPING::", "");
                _mostrarEscribiendo(nombreAmigo);
                for (var c in _clientesConectados)
                  if (c != cliente) c.write("CMD::TYPING::$nombreAmigo");
              } else if (cmd.startsWith("JSON::")) {
                try {
                  var map = jsonDecode(cmd.substring(6));
                  setState(() {
                    _mensajes.add(
                      MensajeChat(
                        nombre: map['n'],
                        texto: map['t'],
                        soyYo: false,
                        esSistema: false,
                        hora: _obtenerHoraActual(),
                      ),
                    );
                  });
                  _guardarHistorial();
                  _hacerScrollHaciaAbajo();
                  // Rebotar a los demás clientes
                  for (var c in _clientesConectados)
                    if (c != cliente) c.write("CMD::JSON::${cmd.substring(6)}");
                } catch (e) {}
              }
            }
          },
          onDone: () {
            if (!mounted) return;
            setState(() {
              _clientesConectados.remove(cliente);
              _mensajes.add(
                MensajeChat(
                  texto: "Alguien se desconectó",
                  soyYo: false,
                  esSistema: true,
                  hora: _obtenerHoraActual(),
                ),
              );
            });
            _guardarHistorial();
            _hacerScrollHaciaAbajo();
          },
        );
      });
    } catch (e) {
      if (!mounted) return;
    }
  }

  Future<void> _cerrarSalaYBorrar() async {
    for (var cliente in _clientesConectados) {
      try {
        cliente.write("CMD::CLOSE_ROOM");
      } catch (e) {}
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('historial_host');

    _serverSocket?.close();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _enviarMensaje() {
    if (_mensajeController.text.isNotEmpty) {
      String nombre = _nombreController.text.isEmpty
          ? "Host"
          : _nombreController.text;
      String textoPuro = _mensajeController.text;

      setState(() {
        _mensajes.add(
          MensajeChat(
            nombre: nombre,
            texto: textoPuro,
            soyYo: true,
            esSistema: false,
            hora: _obtenerHoraActual(),
          ),
        );
        _mensajeController.clear();
      });
      _guardarHistorial();
      _hacerScrollHaciaAbajo();

      String payload =
          "CMD::JSON::${jsonEncode({'n': nombre, 't': textoPuro})}";
      for (var cliente in _clientesConectados) {
        cliente.write(payload);
      }
    }
  }

  void _notificarQueEscribo(String texto) {
    if (texto.isNotEmpty) {
      String nombre = _nombreController.text.isEmpty
          ? "Host"
          : _nombreController.text;
      for (var cliente in _clientesConectados) {
        cliente.write("CMD::TYPING::$nombre");
      }
    }
  }

  @override
  void dispose() {
    _serverSocket?.close();
    for (var cliente in _clientesConectados) cliente.close();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: colorAcento,
              radius: 18,
              child: Icon(Icons.group, color: fondoOscuro, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Grupo LAN (Host)', style: TextStyle(fontSize: 18)),
                if (_quienEscribe.isNotEmpty)
                  Text(
                    _quienEscribe,
                    style: const TextStyle(
                      fontSize: 12,
                      color: colorAcento,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: fondoAppbar,
                  title: const Text(
                    'Invitar al grupo',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        color: Colors.white,
                        child: _ipLocal.isNotEmpty
                            ? QrImageView(
                                data: _ipLocal,
                                version: QrVersions.auto,
                                size: 200.0,
                              )
                            : const CircularProgressIndicator(),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'IP manual: $_ipLocal',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
            tooltip: 'Destruir Sala',
            onPressed: () async {
              bool? confirmar = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: fondoAppbar,
                  title: const Text(
                    '¿Cerrar Sala?',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'Esto borrará los mensajes permanentemente para TODOS.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(color: colorAcento),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Destruir Chat',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmar == true) _cerrarSalaYBorrar();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: fondoOscuro,
          image: DecorationImage(
            image: const NetworkImage(
              'https://i.pinimg.com/736x/8c/98/99/8c98994518b575bfd8c949e91d20548b.jpg',
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              fondoOscuro.withOpacity(0.92),
              BlendMode.dstATop,
            ),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _mensajes.length,
                itemBuilder: (context, index) {
                  final msg = _mensajes[index];

                  if (msg.esSistema) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: fondoAppbar,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          msg.texto,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    alignment: msg.soyYo
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 10,
                        top: 8,
                        bottom: 8,
                      ),
                      decoration: BoxDecoration(
                        color: msg.soyYo ? burbujaMia : burbujaOtro,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: msg.soyYo
                              ? const Radius.circular(12)
                              : Radius.zero,
                          bottomRight: msg.soyYo
                              ? Radius.zero
                              : const Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: msg.soyYo
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          // AQUI ESTÁ EL NOMBRE COLOREADO
                          if (!msg.soyYo && msg.nombre.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                msg.nombre,
                                style: TextStyle(
                                  color: _getColorPorNombre(msg.nombre),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.end,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 10,
                                  bottom: 2,
                                ),
                                child: Text(
                                  msg.texto,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    msg.hora,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                  if (msg.soyYo) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.done_all,
                                      size: 16,
                                      color: Colors.lightBlueAccent,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: fondoAppbar,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _mensajeController,
                        onChanged: _notificarQueEscribo,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Mensaje',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorAcento,
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _enviarMensaje,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
  final TextEditingController _nombreController =
      TextEditingController(); // Limpio por defecto
  final TextEditingController _mensajeController = TextEditingController();

  List<MensajeChat> _mensajes = [];
  bool _conectado = false;
  bool _mostrarFormulario = true;

  final ScrollController _scrollController = ScrollController();
  String _quienEscribe = "";
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();

    // Cargar su nombre personalizado
    _nombreController.text = prefs.getString('mi_nombre_cliente') ?? "";

    final String? historialJson = prefs.getString('historial_cliente');
    if (historialJson != null) {
      final List<dynamic> decodificado = jsonDecode(historialJson);
      if (decodificado.isNotEmpty) {
        setState(() {
          _mensajes = decodificado
              .map((item) => MensajeChat.fromJson(item))
              .toList();
          _mostrarFormulario = false;
        });
        _hacerScrollHaciaAbajo();
      }
    }
  }

  Future<void> _guardarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('mi_nombre_cliente', _nombreController.text);
    final String historialJson = jsonEncode(
      _mensajes.map((m) => m.toJson()).toList(),
    );
    prefs.setString('historial_cliente', historialJson);
  }

  Future<void> _borrarHistorialSeguridad() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('historial_cliente');
    setState(() {
      _mensajes.clear();
      _conectado = false;
    });
  }

  void _hacerScrollHaciaAbajo() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _mostrarEscribiendo(String nombre) {
    setState(() {
      _quienEscribe = "$nombre está escribiendo...";
    });
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted)
        setState(() {
          _quienEscribe = "";
        });
    });
  }

  void _conectarAlHost() async {
    try {
      _socket = await Socket.connect(_ipController.text, 8080);
      if (!mounted) return;
      setState(() {
        _conectado = true;
        _mostrarFormulario = false;
        _mensajes.add(
          MensajeChat(
            texto: "Te uniste al grupo",
            soyYo: false,
            esSistema: true,
            hora: _obtenerHoraActual(),
          ),
        );
      });
      _guardarHistorial();

      _socket!.listen(
        (List<int> data) async {
          if (!mounted) return;
          String stringData = String.fromCharCodes(data);

          List<String> comandos = stringData.split("CMD::");
          for (String cmd in comandos) {
            if (cmd.isEmpty) continue;

            // 1. SOLUCIÓN AL BUG DE EXPULSIÓN
            if (cmd == "CLOSE_ROOM") {
              await _borrarHistorialSeguridad();
              if (!mounted) return;
              _socket?.destroy();

              // Lanza el popup y expulsa al usuario a la pantalla principal
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  backgroundColor: fondoAppbar,
                  title: const Text(
                    'Sala Destruida',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'El Host ha cerrado la sala. Todos los mensajes han sido borrados por seguridad.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Cierra el popup
                        Navigator.pop(
                          context,
                        ); // Cierra el chat y regresa al menú de inicio
                      },
                      child: const Text(
                        'Entendido',
                        style: TextStyle(color: fondoOscuro),
                      ),
                    ),
                  ],
                ),
              );
              return;
            }

            if (cmd.startsWith("TYPING::")) {
              String nombreAmigo = cmd.replaceAll("TYPING::", "");
              _mostrarEscribiendo(nombreAmigo);
            } else if (cmd.startsWith("JSON::")) {
              try {
                var map = jsonDecode(cmd.substring(6));
                setState(() {
                  _mensajes.add(
                    MensajeChat(
                      nombre: map['n'],
                      texto: map['t'],
                      soyYo: false,
                      esSistema: false,
                      hora: _obtenerHoraActual(),
                    ),
                  );
                });
                _guardarHistorial();
                _hacerScrollHaciaAbajo();
              } catch (e) {}
            }
          }
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _conectado = false;
            _mensajes.add(
              MensajeChat(
                texto: "Se perdió la conexión, pero tu historial está a salvo.",
                soyYo: false,
                esSistema: true,
                hora: _obtenerHoraActual(),
              ),
            );
          });
          _guardarHistorial();
          _socket?.destroy();
          _hacerScrollHaciaAbajo();
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensajes.add(
          MensajeChat(
            texto: "No se pudo conectar al Host.",
            soyYo: false,
            esSistema: true,
            hora: _obtenerHoraActual(),
          ),
        );
        _mostrarFormulario = true;
      });
    }
  }

  void _enviarMensaje() {
    if (_mensajeController.text.isNotEmpty && _socket != null) {
      String nombre = _nombreController.text.isEmpty
          ? "Amigo"
          : _nombreController.text;
      String textoPuro = _mensajeController.text;

      setState(() {
        _mensajes.add(
          MensajeChat(
            nombre: nombre,
            texto: textoPuro,
            soyYo: true,
            esSistema: false,
            hora: _obtenerHoraActual(),
          ),
        );
        _mensajeController.clear();
      });
      _guardarHistorial();
      _hacerScrollHaciaAbajo();

      String payload =
          "CMD::JSON::${jsonEncode({'n': nombre, 't': textoPuro})}";
      _socket!.write(payload);
    }
  }

  void _notificarQueEscribo(String texto) {
    if (texto.isNotEmpty && _socket != null) {
      String nombre = _nombreController.text.isEmpty
          ? "Amigo"
          : _nombreController.text;
      _socket!.write("CMD::TYPING::$nombre");
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
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: colorAcento,
              radius: 18,
              child: Icon(Icons.group, color: fondoOscuro, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Grupo LAN', style: TextStyle(fontSize: 18)),
                if (_quienEscribe.isNotEmpty)
                  Text(
                    _quienEscribe,
                    style: const TextStyle(
                      fontSize: 12,
                      color: colorAcento,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ===============================================
          // PANTALLA 1: FORMULARIO
          // ===============================================
          if (_mostrarFormulario && !_conectado)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: fondoAppbar,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Ingresar al chat',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 25),
                        _crearCampoDeTexto(
                          _nombreController,
                          'Tu nombre',
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
                              backgroundColor: fondoOscuro,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Conectar manual'),
                          ),
                        ),
                        if (_mensajes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 15),
                            child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => _mostrarFormulario = false),
                              icon: const Icon(
                                Icons.history,
                                color: colorAcento,
                              ),
                              label: const Text(
                                'Ver historial (Desconectado)',
                                style: TextStyle(color: colorAcento),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          // ===============================================
          // PANTALLA 2: EL CHAT
          // ===============================================
          else ...[
            // Banner superior si pierde conexión (SOLUCIÓN AL BUG DE SALIDA)
            if (!_conectado)
              Container(
                color: Colors.redAccent.withOpacity(0.15),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Sin conexión",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // BOTÓN PARA ESCAPAR SI SE BUGEA
                        IconButton(
                          icon: const Icon(
                            Icons.exit_to_app,
                            color: Colors.redAccent,
                          ),
                          tooltip: 'Salir',
                          onPressed: () => Navigator.pop(context),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: () =>
                              setState(() => _mostrarFormulario = true),
                          child: const Text("Reconectar"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Lista de Mensajes
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: fondoOscuro,
                  image: DecorationImage(
                    image: const NetworkImage(
                      'https://i.pinimg.com/736x/8c/98/99/8c98994518b575bfd8c949e91d20548b.jpg',
                    ),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      fondoOscuro.withOpacity(0.92),
                      BlendMode.dstATop,
                    ),
                  ),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _mensajes.length,
                  itemBuilder: (context, index) {
                    final msg = _mensajes[index];

                    if (msg.esSistema) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: fondoAppbar,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            msg.texto,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      alignment: msg.soyYo
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        padding: const EdgeInsets.only(
                          left: 12,
                          right: 10,
                          top: 8,
                          bottom: 8,
                        ),
                        decoration: BoxDecoration(
                          color: msg.soyYo ? burbujaMia : burbujaOtro,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: msg.soyYo
                                ? const Radius.circular(12)
                                : Radius.zero,
                            bottomRight: msg.soyYo
                                ? Radius.zero
                                : const Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: msg.soyYo
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            // AQUI ESTÁ EL NOMBRE COLOREADO
                            if (!msg.soyYo && msg.nombre.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  msg.nombre,
                                  style: TextStyle(
                                    color: _getColorPorNombre(msg.nombre),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            Wrap(
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.end,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: 10,
                                    bottom: 2,
                                  ),
                                  child: Text(
                                    msg.texto,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      msg.hora,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                    ),
                                    if (msg.soyYo) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.done_all,
                                        size: 16,
                                        color: Colors.lightBlueAccent,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            if (_conectado)
              Container(
                padding: const EdgeInsets.all(8),
                color: fondoOscuro,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: fondoAppbar,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextField(
                          controller: _mensajeController,
                          onChanged: _notificarQueEscribo,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Mensaje',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colorAcento,
                      child: IconButton(
                        icon: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _enviarMensaje,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                color: fondoOscuro,
                alignment: Alignment.center,
                child: const Text(
                  "Conéctate a una sala para enviar mensajes.",
                  style: TextStyle(color: Colors.white54),
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
        fillColor: fondoOscuro,
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
      appBar: AppBar(title: const Text('Enfoca el QR')),
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
              border: Border.all(color: colorAcento, width: 4),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }
}
