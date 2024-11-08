import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NearbyClinicPage extends StatefulWidget {
  final String? userCity;

  const NearbyClinicPage({Key? key, this.userCity}) : super(key: key);

  @override
  State<NearbyClinicPage> createState() => _NearbyClinicPageState();
}

class _NearbyClinicPageState extends State<NearbyClinicPage> {
  MapController mapController = MapController();
  String _locationMessage = "Fetching your location...";
  double? latitude;
  double? longitude;
  String? city;
  String? state;
  String? country;
  List<Marker> clinicMarkers = [];

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        await _getCurrentLocation();
      } else {
        _useDefaultLocation();
      }
    } catch (e) {
      print("Error getting location: $e");
      _useDefaultLocation();
    }

    await _fetchAndDisplayAmenities();
  }

  void _useDefaultLocation() {
    setState(() {
      latitude = 3.140853;
      longitude = 101.693207; // Coordinates for Kuala Lumpur
      _locationMessage = "Showing default location: Kuala Lumpur, Malaysia";
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });

      await _getAddressFromLatLng(latitude!, longitude!);
    } catch (e) {
      print("Error getting current location: $e");
      _useDefaultLocation();
    }
  }

  Future<void> _getAddressFromLatLng(double lat, double lon) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      var result = json.decode(response.body);
      setState(() {
        city = result['address']['city'] ??
            result['address']['town'] ??
            result['address']['village'] ??
            'Unknown';
        state = result['address']['state'] ?? 'Unknown';
        country = result['address']['country'] ?? 'Unknown';
        _locationMessage =
            "Clinics near $city, $state, $country";
      });
    } else {
      throw Exception('Failed to fetch address');
    }
  }

  String _formatOperatingHours(String hours) {
    Map<String, String> daysOfWeek = {
      'mo': 'Monday',
      'tu': 'Tuesday',
      'we': 'Wednesday',
      'th': 'Thursday',
      'fr': 'Friday',
      'sa': 'Saturday',
      'su': 'Sunday',
    };
    List<String> formattedDays = [];
    if (hours.contains(',')) {
      var dayRanges = hours.split(',');
      for (var range in dayRanges) {
        formattedDays.add(_formatDayRange(range, daysOfWeek));
      }
    } else {
      formattedDays.add(_formatDayRange(hours, daysOfWeek));
    }

    return formattedDays.join(', ');
  }

  String _formatDayRange(String range, Map<String, String> daysOfWeek) {
    if (range.contains('-')) {
      var days = range.split('-');
      String startDay = daysOfWeek[days[0].toLowerCase()] ?? days[0];
      String endDay = daysOfWeek[days[1].toLowerCase()] ?? days[1];
      return '$startDay - $endDay';
    } else {
      return daysOfWeek[range.toLowerCase()] ?? range;
    }
  }

  Widget _buildCustomMarker(IconData icon, Color iconColor) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: iconColor, size: 30),
      ),
    );
  }

  Future<void> _fetchAndDisplayAmenities() async {
    if (latitude == null || longitude == null) return;

    try {
      List amenities = await fetchNearbyAmenities(latitude!, longitude!);
      setState(() {
        clinicMarkers = amenities.map((amenity) {
          IconData icon;
          Color color;

          switch (amenity['tags']['amenity']) {
            case 'hospital':
              icon = Icons.local_hospital;
              color = Colors.red;
              break;
            case 'doctors':
              icon = Icons.medical_services;
              color = Colors.red;
              break;
            case 'clinic':
            default:
              icon = Icons.local_hospital;
              color = Colors.red;
              break;
          }

          return Marker(
              point: LatLng(amenity['lat'], amenity['lon']),
              width: 38,
              height: 38,
              child: GestureDetector(
                onTap: () => _showAmenityDetails(amenity),
                child: _buildCustomMarker(icon, color),
              ));
        }).toList();
      });
      
      // Center the map on the user's location after fetching amenities
      mapController.move(LatLng(latitude!, longitude!), 13.0);
    } catch (e) {
      print("Error fetching amenities: $e");
    }
  }

  String _formatAddress(Map<String, dynamic> tags) {
    List<String> addressParts = [
      tags['addr:house_number'],
      tags['addr:street'],
      tags['addr:unit'],
      tags['addr:suburb'],
      tags['addr:city'] ?? tags['addr:town'] ?? tags['addr:village'],
      tags['addr:postcode'],
      tags['addr:state'],
      tags['addr:country'],
    ]
        .where((part) => part != null && part.isNotEmpty)
        .map((part) => part.toString())
        .toList();

    return addressParts.isNotEmpty
        ? addressParts.join(', ')
        : 'Address not available';
  }

  String _decodeName(String name) {
    try {
      return utf8.decode(name.runes.toList());
    } catch (e) {
      return name;
    }
  }

  void _showAmenityDetails(Map amenity) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        String name = _decodeName(amenity['tags']['name'] ?? 'Unknown');
        String address = _formatAddress(amenity['tags']);
        String operatingHours = amenity['tags']['opening_hours'] != null
            ? _formatOperatingHours(amenity['tags']['opening_hours'])
            : 'Operating hours not available';

        return Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Type: ${amenity['tags']['amenity'] ?? 'Unknown'}'),
              SizedBox(height: 4),
              Text('Address: $address'),
              if (amenity['tags']['phone'] != null) ...[
                SizedBox(height: 4),
                Text('Phone: ${amenity['tags']['phone']}'),
              ],
              if (amenity['tags']['opening_hours'] != null) ...[
                SizedBox(height: 4),
                Text('Operating hours: $operatingHours'),
              ],
              if (amenity['tags']['website'] != null) ...[
                SizedBox(height: 4),
                Text('Website: ${amenity['tags']['website']}'),
              ],
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List> fetchNearbyAmenities(double latitude, double longitude) async {
    final url = 'https://overpass-api.de/api/interpreter?data=[out:json];'
        'node["amenity"~"clinic|hospital|doctors"](around:15000,$latitude,$longitude);out;';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return jsonResponse['elements'];
    } else {
      throw Exception('Failed to load amenities');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Clinics', style: TextStyle(
            color: Color(0xFFEBE0D0),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFFA81B60),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: LatLng(latitude ?? 3.140853,
                    longitude ?? 101.693207), // Default to Kuala Lumpur
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                ),
                MarkerLayer(
                  markers: [
                    if (latitude != null && longitude != null)
                      Marker(
                        point: LatLng(latitude!, longitude!),
                        width: 80,
                        height: 80,
                        child: Icon(Icons.location_pin, color: Colors.red),
                      ),
                    ...clinicMarkers,
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  _locationMessage,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await _getCurrentLocation();
                    await _fetchAndDisplayAmenities();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFA81B60), // Set background color
                    foregroundColor: Colors.white, // Set text color
                  ),
                  child: Text('Scan Clinics'),
                  // backgroundColor: Color(0xFFA81B60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}