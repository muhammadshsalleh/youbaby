import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatefulWidget {
  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  Future<List<dynamic>>? _notifications;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  // Function to fetch notifications from Supabase
  Future<void> _fetchNotifications() async {
    try {
      final response = await supabase
          .from('notification')
          .select('*')
          .order('created_at', ascending: false);

      setState(() {
        _notifications = Future.value(response);
      });
    } catch (error) {
      setState(() {
        _notifications = Future.error('Failed to load notifications');
      });
    }
  }

  // Function to insert notification into the database
  Future<void> _insertNotification() async {
    final String title = _titleController.text;
    final String description = _descriptionController.text;

    if (title.isNotEmpty && description.isNotEmpty) {
      final response = await supabase.from('notification').insert({
        'title': title,
        'description': description,
      });

      _titleController.clear();
      _descriptionController.clear();
      _fetchNotifications(); // Refresh notifications after insertion

      // Show success dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Success'),
            content: Text('Send successful'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );

      if (response != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send notification')),
        );
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Failed to send notification')),
        // );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in both title and description')),
      );
    }
  }

  // Function to delete a notification from the database
  Future<void> _deleteNotification(int id) async {
    try {
      final response =
          await supabase.from('notification').delete().eq('id', id);

      _fetchNotifications(); // Refresh notifications after deletion
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification deleted successfully')),
      );

      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete notification')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $error')),
      );
    }
  }

  String formatNotificationDate(String createdAt) {
    DateTime dateTime = DateTime.parse(createdAt).toLocal();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 1) {
      return DateFormat('d MMMM yyyy')
          .format(dateTime); // E.g., 20 September 2024
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification'),
        backgroundColor: Color(0xFFA81B60),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input box for title and description
            // Container(
            //   padding: const EdgeInsets.all(12.0),
            //   decoration: BoxDecoration(
            //     color: Colors.white,
            //     borderRadius: BorderRadius.circular(8.0),
            //     boxShadow: [BoxShadow(blurRadius: 2, color: Colors.grey)],
            //   ),
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       TextField(
            //         controller: _titleController,
            //         decoration: InputDecoration(
            //           labelText: 'Title',
            //           border: OutlineInputBorder(),
            //         ),
            //       ),
            //       SizedBox(height: 10),
            //       TextField(
            //         controller: _descriptionController,
            //         decoration: InputDecoration(
            //           labelText: 'Text Description',
            //           border: OutlineInputBorder(),
            //         ),
            //       ),
            //       SizedBox(height: 10),
            //       Align(
            //         alignment: Alignment.centerRight,
            //         child: ElevatedButton(
            //           onPressed: _insertNotification,
            //           child: Text('Send'),
            //           style: ElevatedButton.styleFrom(
            //             backgroundColor: Color(0xFFA81B60),
            //             foregroundColor: Color.fromARGB(255, 255, 255, 255),
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            //SizedBox(height: 20),
            // Recent Notification Title
            Text(
              'Recent Notification',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFFA81B60),
              ),
            ),
            SizedBox(height: 10),
            // Displaying notifications in a scrollable list
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _notifications,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No notifications available'));
                  } else {
                    final notifications = snapshot.data!;
                    return ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return Dismissible(
                          key: Key(notification['id'].toString()),
                          direction: DismissDirection.endToStart,
                          onDismissed: (direction) {
                            _deleteNotification(notification['id']);
                          },
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.symmetric(horizontal: 20.0),
                            child: Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                                boxShadow: [
                                  BoxShadow(blurRadius: 2, color: Colors.grey)
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notification['title'] ?? 'No Title',
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    notification['description'] ??
                                        'No Description',
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      formatNotificationDate(
                                          notification['created_at']),
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
