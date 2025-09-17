import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/living_workshop_service.dart';
import 'workshop_dashboard_screen.dart';

class WorkshopTestScreen extends StatefulWidget {
  @override
  _WorkshopTestScreenState createState() => _WorkshopTestScreenState();
}

class _WorkshopTestScreenState extends State<WorkshopTestScreen> {
  final LivingWorkshopService _workshopService = LivingWorkshopService();
  String _testStatus = 'Ready to test';
  bool _isLoading = false;

  Future<void> _testWorkshopFlow() async {
    setState(() {
      _isLoading = true;
      _testStatus = 'Testing workshop flow...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _testStatus = 'Error: User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Test 1: Check if workshop exists
      setState(() {
        _testStatus = 'Checking if workshop exists...';
      });
      
      final workshopExists = await _workshopService.workshopExists(user.uid);
      
      setState(() {
        _testStatus = 'Workshop exists: $workshopExists';
      });
      
      await Future.delayed(Duration(seconds: 1));

      // Test 2: Try to load workshop content
      setState(() {
        _testStatus = 'Attempting to load workshop content...';
      });
      
      final workshopContent = await _workshopService.loadWorkshopContent(user.uid);
      
      setState(() {
        _testStatus = 'Workshop loaded: ${workshopContent != null ? 'Yes' : 'No'}';
      });
      
      await Future.delayed(Duration(seconds: 1));

      // Test 3: Navigate to dashboard
      setState(() {
        _testStatus = 'Navigating to workshop dashboard...';
      });
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkshopDashboardScreen(
            artisanId: user.uid,
            existingWorkshopData: workshopContent ?? {},
          ),
        ),
      );

    } catch (e) {
      setState(() {
        _testStatus = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _clearWorkshopData() async {
    setState(() {
      _isLoading = true;
      _testStatus = 'Clearing workshop data...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _testStatus = 'Error: User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Clear from both possible storage locations
      await _workshopService.clearWorkshopData(user.uid);
      
      setState(() {
        _testStatus = 'Workshop data cleared successfully';
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _testStatus = 'Error clearing data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(
          'Workshop Navigation Test',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.purple,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.science,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 30),
              Text(
                'Workshop Navigation Test',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _testStatus,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
              if (_isLoading)
                CircularProgressIndicator(color: Colors.white)
              else ...[
                Container(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _testWorkshopFlow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Test Workshop Flow',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _clearWorkshopData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Clear Workshop Data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}