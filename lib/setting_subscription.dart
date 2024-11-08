import 'package:flutter/material.dart';
import 'package:youbaby/settings_page.dart';

class SubscriptionPaymentPage extends StatefulWidget {
  @override
  _SubscriptionPaymentPageState createState() =>
      _SubscriptionPaymentPageState();
}

class _SubscriptionPaymentPageState extends State<SubscriptionPaymentPage> {
  String _subscriptionType = "None";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Subscription Payment Settings", 
        style: TextStyle(
            color: Color(0xFFEBE0D0),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          )
        ),
        backgroundColor: Color(0xFFA81B60),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subscription:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ), //text
            SizedBox(
                height: 8), // Space between text and subscription type display
            Text(
              _subscriptionType,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 24), // Space before the button
            ElevatedButton(
              onPressed: () {
                // Logic to cancel the subscription can be added here
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text("Cancel Subscription"),
                      content: Text(
                          "Are you sure you want to cancel your subscription?"),
                      actions: [
                        TextButton(
                          child: Text("No"),
                          onPressed: () {
                            Navigator.of(context).pop(); // Close the dialog
                          },
                        ),
                        TextButton(
                          child: Text("Yes"),
                          onPressed: () {
                            // Add cancellation logic here
                            Navigator.of(context).pop(); // Close the dialog
                            // Show cancellation success message or navigate back
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              child: Text(
                "Cancel Subscription",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                //primary: Colors.red, // Button color
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(
                    vertical: 16, horizontal: 10), // Button height
              ),
            ),
          ],
        ),
      ),
    );
  }
}
            
         

// class SubscriptionPaymentPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Profile Settings"),
//         backgroundColor: Color(0xFFA81B60),
//         ),
//       body: Center(child: Text("Profile Settings Page")),
//     );
//   }
// }