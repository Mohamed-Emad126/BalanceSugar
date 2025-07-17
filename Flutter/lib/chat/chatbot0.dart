import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' hide TextDirection;
import '../services/auth_service.dart';
import '../services/api_config.dart';

class ChatMessage {
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final int id;

  ChatMessage({
    required this.message,
    required this.isUser,
    required this.timestamp,
    required this.id,
  });
}

class ChatService {
  static Future<List<ChatMessage>> fetchOldMessages() async {
    try {
      final accessToken = await AuthService.getAccessToken();
      if (accessToken == null) {
        throw Exception('No authentication token available');
      }

      print('Fetching messages with token: $accessToken');

      final response = await http.get(
        Uri.parse(ApiConfig.getConversation),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 401) {
        final newToken = await AuthService.refreshAccessToken();
        if (newToken == null) {
          throw Exception('Authentication failed');
        }
        return fetchOldMessages();
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        List<ChatMessage> messages = [];

        for (var msg in data) {
          print("📦 Raw timestamp from backend: ${msg['timestamp']}");

          // Convert UTC timestamp to local time
          DateTime parseTimestamp(String timestamp) {
            try {
              return DateTime.parse(timestamp);
            } catch (e) {
              try {
                return DateFormat("yyyy-MM-dd hh:mm a").parse(timestamp);
              } catch (e2) {
                print('❌ Failed to parse timestamp: $timestamp');
                return DateTime.now(); // fallback
              }
            }
          }

          // First add the user's question
          if (msg['user_input'] != null &&
              msg['user_input'].toString().isNotEmpty) {
            messages.add(
              ChatMessage(
                message: msg['user_input'],
                isUser: true,
                timestamp: parseTimestamp(msg['timestamp']),
                id: msg['id'] ?? 0,
              ),
            );
          }

          // Then add the AI's response
          if (msg['ai_response'] != null &&
              msg['ai_response'].toString().isNotEmpty) {
            messages.add(
              ChatMessage(
                message: msg['ai_response'],
                isUser: false,
                timestamp: parseTimestamp(msg['timestamp']),
                id: msg['id'] ?? 0,
              ),
            );
          }
        }
        return messages;
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error fetching messages: $e');
      return [];
    }
  }

  static Future<String> sendMessageToBackend(String message) async {
    try {
      final accessToken = await AuthService.getAccessToken();
      if (accessToken == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.post(
        Uri.parse(ApiConfig.createChatbot),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: utf8.encode(json.encode({
          'input_text': message,
          'timestamp': DateTime.now().toUtc().toIso8601String(), // ✅ UTC ISO
        })),
      );

      if (response.statusCode == 401) {
        final newToken = await AuthService.refreshAccessToken();
        if (newToken == null) {
          throw Exception('Authentication failed');
        }
        return sendMessageToBackend(message);
      }

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final responseData = json.decode(responseBody);
        return responseData['response'];
      } else {
        throw Exception('Failed to send message');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to send message');
    }
  }

  static Future<void> deleteMessages() async {
    try {
      final accessToken = await AuthService.getAccessToken();
      if (accessToken == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.delete(
        Uri.parse(ApiConfig.deleteConversation),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 401) {
        final newToken = await AuthService.refreshAccessToken();
        if (newToken == null) {
          throw Exception('Authentication failed');
        }
        return deleteMessages();
      }

      if (response.statusCode == 204) {
        print("Messages deleted successfully");
      } else {
        throw Exception('Failed to delete messages');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to delete messages');
    }
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _hasError = false;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isFirstLoad) {
      _fetchMessages();
      _isFirstLoad = false;
    }
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final oldMessages = await ChatService.fetchOldMessages();
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(oldMessages);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('⚠️ Error fetching messages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // Scroll to top since list is reversed
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final currentMessage = ChatMessage(
      message: text,
      isUser: true,
      timestamp: DateTime
          .now(), // مش هنعمل لا local ولا utc، لو بتستخدمي toIsoString في الإرسال
      id: 0,
    );

    setState(() {
      _messages.add(currentMessage);
      _controller.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final reply = await ChatService.sendMessageToBackend(text);
      final aiMessage = ChatMessage(
        message: reply,
        isUser: false,
        timestamp: DateTime.now(),
        id: 0,
      );

      if (mounted) {
        setState(() {
          _messages.add(aiMessage);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      print('⚠️ Error sending message: $e');
      if (mounted) {
        setState(() {
          _messages.removeLast();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title bar with icon
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.red[700],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.white, size: 26),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Clear Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                child: Text(
                  'Are you sure you want to delete all messages?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18, left: 16, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await ChatService.deleteMessages();
                            setState(() {
                              _messages.clear();
                            });
                            Navigator.of(context).pop();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to delete messages.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue[900] : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.message,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: message.isUser ? Colors.white : Colors.black87,
                fontSize: 16,
                height: 1.4,
              ),
              textDirection: _isArabic(message.message)
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              textAlign:
                  _isArabic(message.message) ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: message.isUser ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  String _formatTimestamp(DateTime timestamp) {
    // Only show the time, since the date is now shown as a divider
    return DateFormat('h:mm a').format(timestamp);
  }

  String _formatDateHeader(DateTime date) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'Today';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(date); // Jun 21, 2025
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6EEF5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title:
            const Text('Chat with us!', style: TextStyle(color: Colors.grey)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.blue[900]),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.blue[900]),
            onPressed: _confirmClearChat,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMessages,
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Text(
                            "No messages available.",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true, // Show newest messages first
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final reversedIndex = _messages.length - 1 - index;
                            final currentMessage = _messages[reversedIndex];
                            final prevMessage =
                                reversedIndex < _messages.length - 1
                                    ? _messages[reversedIndex + 1]
                                    : null;

                            final currentDate = DateTime(
                              currentMessage.timestamp.year,
                              currentMessage.timestamp.month,
                              currentMessage.timestamp.day,
                            );

                            DateTime? prevDate;
                            if (prevMessage != null) {
                              prevDate = DateTime(
                                prevMessage.timestamp.year,
                                prevMessage.timestamp.month,
                                prevMessage.timestamp.day,
                              );
                            }

                            final showDateDivider =
                                prevDate == null || currentDate != prevDate;

                            return Column(
                              children: [
                                if (showDateDivider)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Text(
                                      _formatDateHeader(currentDate),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                _buildMessage(currentMessage),
                              ],
                            );
                          },
                        ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(color: Colors.grey),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: InputBorder.none,
                      ),
                      textDirection: _isArabic(_controller.text)
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      onChanged: (text) {
                        setState(() {
                          // Trigger rebuild to update text direction
                        });
                      },
                      onSubmitted: (_) {
                        _sendMessage();
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: Colors.blue[900]),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
