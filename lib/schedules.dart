// import 'package:flutter/material.dart';
// import 'package:table_calendar/table_calendar.dart';
//
// class ScheduleScreen extends StatefulWidget {
//   @override
//   _ScheduleScreenState createState() => _ScheduleScreenState();
// }
//
// class _ScheduleScreenState extends State<ScheduleScreen> {
//   CalendarFormat _calendarFormat = CalendarFormat.month;
//   DateTime _focusedDay = DateTime.now();
//   DateTime? _selectedDay;
//   Map<DateTime, List<String>> _events = {};
//
//   List<String> _getEventsForDay(DateTime day) {
//     return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
//   }
//
//   void _addEvent(String title) {
//     final eventDay = DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
//     if (_events[eventDay] == null) {
//       _events[eventDay] = [title];
//     } else {
//       _events[eventDay]!.add(title);
//     }
//     setState(() {});
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Schedule')),
//       body: Column(
//         children: [
//           TableCalendar(
//             firstDay: DateTime.utc(2020, 1, 1),
//             lastDay: DateTime.utc(2030, 12, 31),
//             focusedDay: _focusedDay,
//             calendarFormat: _calendarFormat,
//             selectedDayPredicate: (day) {
//               return isSameDay(_selectedDay, day);
//             },
//             eventLoader: _getEventsForDay,
//             onDaySelected: (selectedDay, focusedDay) {
//               setState(() {
//                 _selectedDay = selectedDay;
//                 _focusedDay = focusedDay;
//               });
//             },
//             onFormatChanged: (format) {
//               setState(() {
//                 _calendarFormat = format;
//               });
//             },
//             onPageChanged: (focusedDay) {
//               _focusedDay = focusedDay;
//             },
//           ),
//           const SizedBox(height: 8.0),
//           ElevatedButton(
//             onPressed: () {
//               if (_selectedDay == null) return;
//
//               showDialog(
//                 context: context,
//                 builder: (context) {
//                   String newEventTitle = '';
//                   return AlertDialog(
//                     title: Text("Add Event"),
//                     content: TextField(
//                       decoration: InputDecoration(hintText: "Event title"),
//                       onChanged: (value) => newEventTitle = value,
//                     ),
//                     actions: [
//                       TextButton(
//                         onPressed: () => Navigator.pop(context),
//                         child: Text("Cancel"),
//                       ),
//                       TextButton(
//                         onPressed: () {
//                           if (newEventTitle.trim().isNotEmpty) {
//                             _addEvent(newEventTitle.trim());
//                             Navigator.pop(context);
//                           }
//                         },
//                         child: Text("Add"),
//                       ),
//                     ],
//                   );
//                 },
//               );
//             },
//             child: Text("Add Event"),
//           ),
//           const SizedBox(height: 8.0),
//           Expanded(
//             child: _selectedDay == null
//                 ? Center(child: Text("Select a day to view events"))
//                 : ListView(
//               children: _getEventsForDay(_selectedDay!).map((event) {
//                 return ListTile(
//                   title: Text(event),
//                   leading: Icon(Icons.event),
//                 );
//               }).toList(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

//   DateTime _focusedDay = DateTime.now();
//   DateTime? _selectedDay;
//   Map<DateTime, List<Map<String, String>>> _events = {};
//
//   String? _userEmail;
//   Future<void> _loadUserEmailAndEvents() async {
//     final prefs = await SharedPreferences.getInstance();
//     _userEmail = prefs.getString('email');
//     if (_userEmail != null) {
//       await _fetchEvents();
//     }
//   }
//   List<Map<String, String>> _getEventsForDay(DateTime day) {
//     return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
//   }
//
//   Future<void> _addEvent(String title, String description) async {
//     if (_selectedDay == null) return;
//
//     final eventDay = DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
//
//     // Add event data to Firestore
//     await FirebaseFirestore.instance.collection('events').add({
//       'title': title,
//       'description': description,
//       'date': Timestamp.fromDate(eventDay),
//       'createdAt': Timestamp.now(),
//     });
//
//     setState(() {
//       // After adding the event, refresh the events list
//       _events[eventDay] = _events[eventDay] ?? [];
//       _events[eventDay]!.add({
//         'title': title,
//         'description': description,
//       });
//     });
//   }
//
//   Future<void> _fetchEvents() async {
//     final snapshot = await FirebaseFirestore.instance.collection('events').get();
//     final Map<DateTime, List<Map<String, String>>> fetchedEvents = {};
//
//     for (var doc in snapshot.docs) {
//       final data = doc.data();
//       final date = (data['date'] as Timestamp).toDate();
//       final title = data['title'] as String;
//       final description = data['description'] as String;
//
//       final eventDate = DateTime.utc(date.year, date.month, date.day);
//       if (fetchedEvents[eventDate] == null) {
//         fetchedEvents[eventDate] = [{'title': title, 'description': description}];
//       } else {
//         fetchedEvents[eventDate]!.add({'title': title, 'description': description});
//       }
//     }
//
//     setState(() {
//       _events = fetchedEvents;
//     });
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUserEmailAndEvents();
//     _fetchEvents();
//     // Fetch events on startup
//   }
//


import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduleScreen extends StatefulWidget {
  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;

DateTime _focusedDay = DateTime.now();
DateTime _selectedDay = DateTime.now();
Map<DateTime, List<Map<String, dynamic>>> _events = {};
String? _userEmail;

@override
void initState() {
  super.initState();
  _loadUserEmailAndEvents();
}

Future<void> _loadUserEmailAndEvents() async {
  final prefs = await SharedPreferences.getInstance();
  final email = prefs.getString('username');

  if (email != null) {
    setState(() {
      _userEmail = email;
    });
    _fetchEvents(email);
  }
}

Future<void> _fetchEvents(String email) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('events')
      .doc(email)
      .collection('user_events')
      .get();

  final allEvents = <DateTime, List<Map<String, dynamic>>>{};

  for (var doc in snapshot.docs) {
    final data = doc.data();
    final date = (data['date'] as Timestamp).toDate();
    final eventDate = DateTime(date.year, date.month, date.day);
    final eventData = {
      'title': data['title'],
      'description': data['description'],
      'id': doc.id,
    };
    if (allEvents[eventDate] == null) {
      allEvents[eventDate] = [eventData];
    } else {
      allEvents[eventDate]!.add(eventData);
    }
  }

  setState(() {
    _events = allEvents;
  });
}
Future<void> _addEvent(DateTime eventDay, String title, String description) async {
  if (_userEmail == null) return;

  final normalizedDay = DateTime(eventDay.year, eventDay.month, eventDay.day);

  try {
    final docRef = await FirebaseFirestore.instance
        .collection('events')
        .doc(_userEmail)
        .collection('user_events')
        .add({
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(normalizedDay),
    });

    log('Event added with ID: ${docRef.id}');

    setState(() {
      _events.putIfAbsent(normalizedDay, () => []);
      _events[normalizedDay]!.add({
        'title': title,
        'description': description,
        'id': docRef.id,
      });
    });
  } catch (e) {
    print('Firestore add error: $e');
  }
}

  Future<void> _deleteEvent(DateTime day, String id) async {
    if (_userEmail == null) return;

    final normalizedDay = DateTime(day.year, day.month, day.day);

    await FirebaseFirestore.instance
        .collection('events')
        .doc(_userEmail)
        .collection('user_events')
        .doc(id)
        .delete();

    setState(() {
      _events[normalizedDay]?.removeWhere((event) => event['id'] == id);
      if (_events[normalizedDay]?.isEmpty ?? false) {
        _events.remove(normalizedDay);
      }
    });
  }


List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
  return _events[DateTime(day.year, day.month, day.day)] ?? [];
}

void _showAddEventDialog() {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Add Event'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: titleController, decoration: InputDecoration(labelText: 'Title')),
          TextField(controller: descriptionController, decoration: InputDecoration(labelText: 'Description')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        TextButton(
          onPressed: () {
            final title = titleController.text;
            final description = descriptionController.text;
            if (title.isNotEmpty && description.isNotEmpty) {
              _addEvent(_selectedDay, title, description);
            }
            Navigator.pop(context);
          },
          child: Text('Add'),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal.shade600,
        title: Text('Schedule', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            eventLoader: _getEventsForDay,
            enabledDayPredicate: (day) {

              return !day.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              leftChevronIcon: Icon(Icons.arrow_left, color: Colors.teal.shade700),
              rightChevronIcon: Icon(Icons.arrow_right, color: Colors.teal.shade700),
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Colors.teal.shade600,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.teal.shade100,
                shape: BoxShape.circle,
              ),
              weekendTextStyle: TextStyle(color: Colors.teal.shade500),
            ),
          ),
          const SizedBox(height: 16.0),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              if (_selectedDay == null) return;

              showDialog(
                context: context,
                builder: (context) {
                  String newEventTitle = '';
                  String newEventDescription = '';
                  return AlertDialog(
                    title: Text("Add Event"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          decoration: InputDecoration(hintText: "Event title"),
                          onChanged: (value) => newEventTitle = value,
                        ),
                        TextField(
                          decoration: InputDecoration(hintText: "Event description (optional)"),
                          onChanged: (value) => newEventDescription = value,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          if (newEventTitle.trim().isNotEmpty) {
                            _addEvent( _selectedDay , newEventTitle.trim(), newEventDescription.trim());
                            Navigator.pop(context);
                          }
                        },
                        child: Text("Add"),
                      ),
                    ],
                  );
                },
              );
            },
            child: Text("Add Event"),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _selectedDay == null
                ? Center(child: Text("Select a day to view events"))
                : ListView(
              children: _getEventsForDay(_selectedDay!).map((event) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {},
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        decoration: BoxDecoration(
                          color: Colors.white, // White background for the card
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.event, color: Colors.teal.shade400),
                                SizedBox(width: 12),
                                Expanded(child: Text(event['title']!, style: TextStyle(fontSize: 16))),
                          IconButton(
                      icon: Icon(Icons.delete, color: Colors.red, size: 18),
                      onPressed: () => _deleteEvent(_selectedDay, event['id']),
                    ),
                              ],
                            ),
                            if (event['description'] != null && event['description']!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  event['description']!,
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

//
//
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:table_calendar/table_calendar.dart';
// import 'dart:collection';
//
// class ScheduleScreen extends StatefulWidget {
//   @override
//   _ScheduleScreenState createState() => _ScheduleScreenState();
// }
//
// class _ScheduleScreenState extends State<ScheduleScreen> {
//   CalendarFormat _calendarFormat = CalendarFormat.month;
//   DateTime _focusedDay = DateTime.now();
//   DateTime _selectedDay = DateTime.now();
//   Map<DateTime, List<Map<String, dynamic>>> _events = {};
//   String? _userEmail;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUserEmailAndEvents();
//   }
//
//   Future<void> _loadUserEmailAndEvents() async {
//     final prefs = await SharedPreferences.getInstance();
//     final email = prefs.getString('username');
//
//     if (email != null) {
//       setState(() {
//         _userEmail = email;
//       });
//       _fetchEvents(email);
//     }
//   }
//
//   Future<void> _fetchEvents(String email) async {
//     final snapshot = await FirebaseFirestore.instance
//         .collection('events')
//         .doc(email)
//         .collection('user_events')
//         .get();
//
//     final allEvents = <DateTime, List<Map<String, dynamic>>>{};
//
//     for (var doc in snapshot.docs) {
//       final data = doc.data();
//       final date = (data['date'] as Timestamp).toDate();
//       final eventDate = DateTime(date.year, date.month, date.day);
//       final eventData = {
//         'title': data['title'],
//         'description': data['description'],
//         'id': doc.id,
//       };
//       if (allEvents[eventDate] == null) {
//         allEvents[eventDate] = [eventData];
//       } else {
//         allEvents[eventDate]!.add(eventData);
//       }
//     }
//
//     setState(() {
//       _events = allEvents;
//     });
//   }
//   Future<void> _addEvent(DateTime eventDay, String title, String description) async {
//     if (_userEmail == null) return;
//
//     final normalizedDay = DateTime(eventDay.year, eventDay.month, eventDay.day);
//
//     try {
//       final docRef = await FirebaseFirestore.instance
//           .collection('events')
//           .doc(_userEmail)
//           .collection('user_events')
//           .add({
//         'title': title,
//         'description': description,
//         'date': Timestamp.fromDate(normalizedDay),
//       });
//
//       print('Event added with ID: ${docRef.id}');
//
//       setState(() {
//         _events.putIfAbsent(normalizedDay, () => []);
//         _events[normalizedDay]!.add({
//           'title': title,
//           'description': description,
//           'id': docRef.id,
//         });
//       });
//     } catch (e) {
//       print('Firestore add error: $e');
//     }
//   }
//
//
//   Future<void> _deleteEvent(DateTime day, String id) async {
//     if (_userEmail == null) return;
//
//     await FirebaseFirestore.instance
//         .collection('events')
//         .doc(_userEmail)
//         .collection('user_events')
//         .doc(id)
//         .delete();
//
//     setState(() {
//       _events[day]?.removeWhere((event) => event['id'] == id);
//       if (_events[day]?.isEmpty ?? false) {
//         _events.remove(day);
//       }
//     });
//   }
//
//   List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
//     return _events[DateTime(day.year, day.month, day.day)] ?? [];
//   }
//
//   void _showAddEventDialog() {
//     final titleController = TextEditingController();
//     final descriptionController = TextEditingController();
//
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Add Event'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(controller: titleController, decoration: InputDecoration(labelText: 'Title')),
//             TextField(controller: descriptionController, decoration: InputDecoration(labelText: 'Description')),
//           ],
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
//           TextButton(
//             onPressed: () {
//               final title = titleController.text;
//               final description = descriptionController.text;
//               if (title.isNotEmpty && description.isNotEmpty) {
//                 _addEvent(_selectedDay, title, description);
//               }
//               Navigator.pop(context);
//             },
//             child: Text('Add'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Schedule')),
//       body: Column(
//         children: [
//           TableCalendar(
//             focusedDay: _focusedDay,
//             firstDay: DateTime(2000),
//             lastDay: DateTime(2100),
//             calendarFormat: _calendarFormat,
//             selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
//             onDaySelected: (selectedDay, focusedDay) {
//               setState(() {
//                 _selectedDay = selectedDay;
//                 _focusedDay = focusedDay;
//               });
//             },
//             eventLoader: _getEventsForDay,
//           ),
//           const SizedBox(height: 8),
//           Expanded(
//             child: ListView(
//               children: _getEventsForDay(_selectedDay).map((event) {
//                 return Card(
//                   margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                   child: ListTile(
//                     title: Text(event['title']),
//                     subtitle: Text(event['description']),
//                     trailing: IconButton(
//                       icon: Icon(Icons.delete, color: Colors.red),
//                       onPressed: () => _deleteEvent(_selectedDay, event['id']),
//                     ),
//                   ),
//                 );
//               }).toList(),
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _showAddEventDialog,
//         child: Icon(Icons.add),
//       ),
//     );
//   }
// }
