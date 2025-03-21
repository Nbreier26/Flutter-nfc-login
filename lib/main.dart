import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:nfc_manager/nfc_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa o Firebase com as credenciais
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyDoVzmzbtzrlWO3ZKqcYLdEXW0FCwazyCo",
      appId: "1:1008143527601:android:d4bba7f297b6b445737c90",
      messagingSenderId: "1008143527601",
      projectId: "flutter-c024f",
      databaseURL: "https://flutter-c024f-default-rtdb.firebaseio.com/",
    ),
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFC Login',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: NfcLoginScreen(),
    );
  }
}

class NfcLoginScreen extends StatefulWidget {
  @override
  _NfcLoginScreenState createState() => _NfcLoginScreenState();
}

class _NfcLoginScreenState extends State<NfcLoginScreen> {
  // Referência para o nó 'nfcTags' no Realtime Database
  final DatabaseReference _databaseRef =
      FirebaseDatabase.instance.ref().child('nfcTags');

  bool _isLoggedIn = false;
  bool _isAddingTag = false;
  bool _hasTags = false; // Flag para indicar se há alguma tag registrada

  @override
  void initState() {
    super.initState();
    _checkExistingTags();
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  // Verifica se há tags registradas no Firebase
  Future<void> _checkExistingTags() async {
    final snapshot = await _databaseRef.get();
    setState(() {
      _hasTags = snapshot.exists;
    });
  }

  // Registra a tag no Firebase
  Future<void> _registerTag(String tagId) async {
    await _databaseRef.child(tagId).set(true);
    setState(() {
      _hasTags = true;
    });
  }

  // Remove todas as tags do Firebase
  Future<void> _resetTags() async {
    await _databaseRef.remove();
    setState(() {
      _isLoggedIn = false;
      _hasTags = false;
    });
    _showMessage('Todas as tags foram removidas');
  }

  // Inicia a leitura NFC
  Future<void> _startNfcScan() async {
    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          final identifier = _getTagId(tag);
          if (identifier == null) return;
          await NfcManager.instance.stopSession();

          // Se não houver nenhuma tag, registra a primeira sem exigir login
          if (!_hasTags) {
            await _registerTag(identifier);
            _showMessage('Tag inicial registrada! Faça login.');
            return;
          }

          if (_isAddingTag) {
            if (!_isLoggedIn) {
              _showMessage('Faça login primeiro para adicionar tags');
              return;
            }
            // Verifica se a tag já existe
            final snap = await _databaseRef.child(identifier).get();
            if (!snap.exists) {
              await _registerTag(identifier);
              _showMessage('Tag adicionada com sucesso!');
            } else {
              _showMessage('Tag já está registrada!');
            }
          } else {
            // Fluxo de login: verifica se a tag existe
            final snap = await _databaseRef.child(identifier).get();
            if (snap.exists) {
              setState(() => _isLoggedIn = true);
              _showMessage('Login realizado com sucesso!');
            } else {
              _showMessage('Tag não reconhecida!');
            }
          }
        },
        onError: (error) async {
          await NfcManager.instance.stopSession();
          _showMessage('Erro na leitura: $error');
        },
      );
    } catch (e) {
      await NfcManager.instance.stopSession();
      _showMessage('Erro: $e');
    }
  }

  // Extrai o identificador da tag lida
  String? _getTagId(NfcTag tag) {
    try {
      final identifier = tag.data['identifier']?.toString() ??
          tag.data['ndef']['identifier']?.toString();
      return identifier?.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    } catch (e) {
      return null;
    }
  }

  // Faz logout e reseta os estados
  void _logout() {
    setState(() {
      _isLoggedIn = false;
      _isAddingTag = false;
    });
  }

  // Alterna o modo de adição de nova tag
  void _toggleAddMode() {
    setState(() => _isAddingTag = !_isAddingTag);
  }

  // Exibe uma mensagem para o usuário
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NFC Login'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _resetTags,
            tooltip: 'Resetar todas as tags',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_isLoggedIn)
              Column(
                children: [
                  Text('Usuário Logado', style: TextStyle(fontSize: 24)),
                  SizedBox(height: 20),
                  ElevatedButton(onPressed: _logout, child: Text('Logout')),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _toggleAddMode,
                    child: Text(_isAddingTag ? 'Cancelar Adição' : 'Adicionar Nova Tag'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAddingTag ? Colors.green : null,
                    ),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _startNfcScan,
                    child: Text('Ler NFC para Adicionar Tag'),
                  ),
                ],
              )
            else
              ElevatedButton(
                onPressed: _startNfcScan,
                child: Text(!_hasTags ? 'Registrar Primeira Tag' : 'Login com NFC'),
              ),
          ],
        ),
      ),
    );
  }
}
