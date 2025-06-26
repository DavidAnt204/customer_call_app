import 'package:flutter/material.dart';

class CallConfirmationDialog extends StatelessWidget {
  final String number;
  final VoidCallback onConfirm;

  const CallConfirmationDialog({
    Key? key,
    required this.number,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      insetPadding: EdgeInsets.all(20), // removes default dialog margin
      backgroundColor: Colors.white,
      child: Container(
        width: screenWidth,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Confirm Call',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                // IconButton(
                //   icon: Icon(Icons.close),
                //   onPressed: () => Navigator.pop(context, false),
                // ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              'Do you want to call $number?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text("Cancel"),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                      onConfirm();
                    },
                    child: Text("Call"),
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
