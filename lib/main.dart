import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
  List<String> _savedTags = [];
  bool _isLoggedIn = false;
  bool _isAddingTag = false;

  @override
  void initState() {
    super.initState();
    _loadSavedTags();
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  Future<void> _loadSavedTags() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedTags = prefs.getStringList('nfcTags') ?? [];
    });
  }

  Future<void> _saveTags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('nfcTags', _savedTags);
    await _loadSavedTags();
  }

  Future<void> _resetTags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nfcTags');
    setState(() {
      _savedTags = [];
      _isLoggedIn = false;
    });
    _showMessage('Todas as tags foram removidas');
  }

  Future<void> _startNfcScan() async {
    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          final identifier = _getTagId(tag);
          if (identifier == null) return;

          await NfcManager.instance.stopSession();

          if (_savedTags.isEmpty) {
            // Primeiro registro sem necessidade de login
            _savedTags.add(identifier);
            await _saveTags();
            _showMessage('Tag inicial registrada! Faça login.');
            return;
          }

          if (_isAddingTag) {
            if (!_isLoggedIn) {
              
              _showMessage('Faça login primeiro para adicionar tags');
              return;
            }
            
            if (!_savedTags.contains(identifier)) {
              _savedTags.add(identifier);
              await _saveTags();
              _showMessage('Tag adicionada com sucesso!');
            } else {
              _showMessage('Tag já está registrada!');
            }
          } else {
            if (_savedTags.contains(identifier)) {
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

  String? _getTagId(NfcTag tag) {
    try {
      final identifier = tag.data['identifier']?.toString() ?? 
                       tag.data['ndef']['identifier']?.toString();
      return identifier?.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    } catch (e) {
      return null;
    }
  }

  void _logout() {
    setState(() {
      _isLoggedIn = false;
      _isAddingTag = false; // Resetar modo de adição ao fazer logout
    });
  }

  void _toggleAddMode() {
    setState(() => _isAddingTag = !_isAddingTag);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NFC Login'),
        actions: [
          if (_savedTags.isNotEmpty)
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
                  ElevatedButton(
                    onPressed: _logout,
                    child: Text('Logout'),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _toggleAddMode,
                    child: Text(_isAddingTag ? 'Cancelar Adição' : 'Adicionar Nova Tag'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAddingTag ? Colors.green : null,
                    ),
                  ),
                ],
              )
            else
              ElevatedButton(
                onPressed: _startNfcScan,
                child: Text(_savedTags.isEmpty 
                    ? 'Registrar Primeira Tag' 
                    : 'Login com NFC'),
              ),
            SizedBox(height: 20),
            if (_savedTags.isNotEmpty)
              Column(
                children: [
                  Text('Tags Registradas:', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 10),
                  Container(
                    height: 100,
                    width: 200,
                    child: ListView.builder(
                      itemCount: _savedTags.length,
                      itemBuilder: (context, index) => Text(
                        'Tag ${index + 1}: ${_savedTags[index].substring(0, 8)}...',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}