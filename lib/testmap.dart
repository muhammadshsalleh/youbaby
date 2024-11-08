import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationTestPage extends StatefulWidget {
  @override
  _LocationTestPageState createState() => _LocationTestPageState();
}

class _LocationTestPageState extends State<LocationTestPage> {
  String _locationMessage = "Press the button to get location";
  double? latitude;
  double? longitude;
  String? city;
  String? state;
  String? country;
  MapController mapController = MapController();

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationMessage = "Location permissions are denied";
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationMessage =
              "Location permissions are permanently denied, we cannot request permissions.";
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });

      try {
        await _getAddressFromLatLng(latitude!, longitude!);
      } catch (e) {
        print("Error in geocoding: $e");
        setState(() {
          _locationMessage =
              "Error getting address.\nLatitude: $latitude, Longitude: $longitude";
        });
      }

      mapController.move(LatLng(latitude!, longitude!), 13.0);
    } catch (e) {
      print("Error getting location: $e");
      setState(() {
        _locationMessage = "Error getting location. Please try again.";
      });
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
        // county = result['address']['county'] ?? 'Unknown'; // Extract county
      _locationMessage =
          "City: $city, State: $state, Country: $country\nLatitude: $latitude, Longitude: $longitude";
      });
    } else {
      throw Exception('Failed to fetch address');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Geolocator Test with Map'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: LatLng(latitude ?? 0.0, longitude ?? 0.0),
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
                  onPressed: _getCurrentLocation,
                  child: Text('Get Location'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
