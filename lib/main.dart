import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

bool isDarkMode = false;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo Journal',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.deepPurple,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(onThemeChanged: () {
        setState(() {
          isDarkMode = !isDarkMode;
        });
      }),
    );
  }
}

class Post {
  final int? id;
  final String title;
  final String body;
  final String? location;

  Post({this.id, required this.title, required this.body, this.location});

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      location: json['location'],
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback onThemeChanged;
  const HomePage({super.key, required this.onThemeChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Post> posts = [];
  bool isLoading = true;
  bool isError = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    setState(() {
      isLoading = true;
      isError = false;
      errorMessage = '';
    });
    try {
      final response = await http.get(Uri.parse('https://dummyjson.com/posts'));
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        List postsList = jsonResponse['posts'];
        setState(() {
          posts = postsList.map((data) => Post.fromJson(data)).take(10).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          isError = true;
          errorMessage = 'Kod błędu: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isError = true;
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geo Journal'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onThemeChanged,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchPosts,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple[100]!, Colors.blue[100]!],
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : (isError && posts.isEmpty)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 50, color: Colors.red[400]),
                          const SizedBox(height: 15),
                          Text('Błąd:\n$errorMessage', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 15),
                          ElevatedButton(
                            onPressed: fetchPosts,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                            child: const Text('Spróbuj ponownie', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  )
                : posts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off, size: 50, color: Colors.deepPurple),
                            const SizedBox(height: 10),
                            const Text('Brak wpisów', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          String subtitle = posts[index].body.length > 30
                            ? posts[index].body.substring(0, 30) + '...'
                            : posts[index].body;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 3,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.deepPurple,
                                child: Icon(Icons.location_on, color: Colors.white),
                              ),
                              title: Text(posts[index].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetailsPage(post: posts[index]),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPage()),
          );
          if (result is Post) {
             setState(() {
               posts.insert(0, result);
               if (posts.isNotEmpty) {
                 isError = false;
               }
             });
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dodano nowy wpis')));
          }
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class AddPage extends StatefulWidget {
  const AddPage({super.key});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _locationMessage = "Brak lokalizacji";
  bool _isSending = false;

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationMessage = "GPS wyłączony";
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationMessage = "Brak uprawnień";
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationMessage = "Brak uprawnień na stałe";
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _locationMessage = "${position.latitude}, ${position.longitude}";
    });
  }

  Future<void> _savePost() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wypełnij pola')));
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://dummyjson.com/posts/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': _titleController.text,
          'body': _bodyController.text,
          'userId': 1,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final newPost = Post(
          id: 101,
          title: _titleController.text,
          body: _bodyController.text,
          location: _locationMessage,
        );
        Navigator.pop(context, newPost);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Błąd wysyłania')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Błąd sieci')));
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dodaj wpis'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple[100]!, Colors.blue[50]!],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Card(
                elevation: 3,
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Tytuł',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Card(
                elevation: 3,
                child: TextField(
                  controller: _bodyController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Opis',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.deepPurple),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_locationMessage, style: const TextStyle(fontSize: 14))),
                      ElevatedButton.icon(
                        onPressed: _getLocation,
                        icon: const Icon(Icons.gps_fixed),
                        label: const Text('GPS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _isSending
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _savePost,
                        icon: const Icon(Icons.check),
                        label: const Text('Zapisz wpis'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
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

class DetailsPage extends StatelessWidget {
  final Post post;

  const DetailsPage({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Szczegóły wpisu'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple[100]!, Colors.blue[100]!],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.article, color: Colors.deepPurple, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(post.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Text(post.body, style: const TextStyle(fontSize: 16, height: 1.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.deepPurple, size: 24),
                          const SizedBox(width: 10),
                          const Text("Lokalizacja", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post.location ?? "Brak danych o lokalizacji",
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
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

