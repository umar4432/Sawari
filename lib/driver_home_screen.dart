import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  bool isOnline = false;
  bool loading = false;

  /* ============================================================
     DRIVER ONLINE / OFFLINE
  ============================================================ */

  Future<void> _toggleOnline() async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Driver login required.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final newStatus = !isOnline;

      await _firestore
          .collection('drivers')
          .doc(user.uid)
          .set(
        {
          'uid': user.uid,
          'isOnline': newStatus,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        setState(() {
          isOnline = newStatus;
        });
      }

      _showMessage(
        isOnline
            ? 'You are now Online.'
            : 'You are now Offline.',
      );
    } catch (e) {
      debugPrint(
        'Driver status error: $e',
      );

      _showMessage(
        'Unable to update driver status.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  /* ============================================================
     ACCEPT RIDE
  ============================================================ */

  Future<void> _acceptRide(
    String rideId,
  ) async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Driver login required.',
      );
      return;
    }

    try {
      setState(() {
        loading = true;
      });

      await _firestore
          .collection('rides')
          .doc(rideId)
          .update(
        {
          'status': 'accepted',

          'driverId': user.uid,

          'driverName':
              user.displayName ?? 'Driver',

          'driverEmail':
              user.email ?? '',

          'acceptedAt':
              FieldValue.serverTimestamp(),

          'updatedAt':
              FieldValue.serverTimestamp(),
        },
      );

      _showMessage(
        'Ride accepted successfully.',
      );
    } catch (e) {
      debugPrint(
        'Accept ride error: $e',
      );

      _showMessage(
        'Unable to accept this ride.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  /* ============================================================
     MESSAGE
  ============================================================ */

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  /* ============================================================
     BUILD
  ============================================================ */

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.grey.shade100,

      /* ========================================================
         APP BAR
      ======================================================== */

      appBar: AppBar(
        title: const Text(
          'Driver App',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            onPressed: () async {
              await _auth.signOut();
            },
            icon: const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),

      /* ========================================================
         BODY
      ======================================================== */

      body: Padding(
        padding:
            const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            /* ==================================================
               DRIVER STATUS CARD
            ================================================== */

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(20),

                child: Row(
                  children: [

                    CircleAvatar(
                      radius: 28,

                      child: Icon(
                        isOnline
                            ? Icons.directions_car
                            : Icons.person,
                        size: 30,
                      ),
                    ),

                    const SizedBox(
                      width: 16,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [

                          const Text(
                            'Driver Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          Text(
                            isOnline
                                ? 'You are Online'
                                : 'You are Offline',

                            style: TextStyle(
                              color: isOnline
                                  ? Colors.green
                                  : Colors.grey.shade700,

                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Switch(
                      value: isOnline,

                      onChanged:
                          loading
                              ? null
                              : (_) {
                                  _toggleOnline();
                                },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            /* ==================================================
               RIDE REQUEST TITLE
            ================================================== */

            const Text(
              'Ride Requests',

              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            /* ==================================================
               RIDE REQUESTS
            ================================================== */

            Expanded(
              child: !isOnline
                  ? _offlineView()
                  : _rideRequests(),
            ),
          ],
        ),
      ),
    );
  }

  /* ============================================================
     OFFLINE VIEW
  ============================================================ */

  Widget _offlineView() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [

          Icon(
            Icons.power_settings_new,
            size: 70,
            color:
                Colors.grey.shade400,
          ),

          const SizedBox(
            height: 12,
          ),

          const Text(
            'Go Online to receive rides',

            style: TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /* ============================================================
     RIDE REQUEST STREAM
  ============================================================ */

  Widget _rideRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('rides')
          .where(
            'status',
            isEqualTo: 'searching',
          )
          .snapshots(),

      builder:
          (context, snapshot) {

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading rides.\n\n'
              '${snapshot.error}',
              textAlign:
                  TextAlign.center,
            ),
          );
        }

        final rides =
            snapshot.data?.docs ?? [];

        if (rides.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,

              children: [

                Icon(
                  Icons.search,
                  size: 70,
                  color:
                      Colors.grey.shade400,
                ),

                const SizedBox(
                  height: 12,
                ),

                const Text(
                  'No ride requests yet',

                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: rides.length,

          itemBuilder:
              (context, index) {

            final ride =
                rides[index];

            final data =
                ride.data()
                    as Map<String, dynamic>;

            final pickup =
                data['pickup'] ??
                    'Pickup';

            final destination =
                data['destination'] ??
                    'Destination';

            final fare =
                data['fare'] ??
                    '0';

            final rideType =
                data['rideType'] ??
                    'Car';

            return Card(
              margin:
                  const EdgeInsets.only(
                bottom: 12,
              ),

              child: Padding(
                padding:
                    const EdgeInsets.all(16),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    /* ==========================================
                       RIDE HEADER
                    ========================================== */

                    Row(
                      children: [

                        CircleAvatar(
                          child: Icon(
                            rideType == 'Bike'
                                ? Icons.two_wheeler
                                : rideType ==
                                        'Rickshaw'
                                    ? Icons
                                        .electric_rickshaw
                                    : Icons
                                        .directions_car,
                          ),
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child: Text(
                            rideType.toString(),

                            style:
                                const TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),

                        Text(
                          'Rs. $fare',

                          style:
                              const TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    /* ==========================================
                       PICKUP
                    ========================================== */

                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        const Icon(
                          Icons.my_location,
                          size: 20,
                          color: Colors.green,
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Expanded(
                          child: Text(
                            'Pickup: $pickup',

                            style:
                                const TextStyle(
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    /* ==========================================
                       DESTINATION
                    ========================================== */

                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        const Icon(
                          Icons.location_on,
                          size: 20,
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Expanded(
                          child: Text(
                            'Destination: '
                            '$destination',

                            style:
                                const TextStyle(
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    /* ==========================================
                       ACCEPT BUTTON
                    ========================================== */

                    SizedBox(
                      width:
                          double.infinity,

                      height: 50,

                      child:
                          ElevatedButton(
                        onPressed:
                            loading
                                ? null
                                : () {
                                    _acceptRide(
                                      ride.id,
                                    );
                                  },

                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const Text(
                                'Accept Ride',

                                style:
                                    TextStyle(
                                  fontSize: 17,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}