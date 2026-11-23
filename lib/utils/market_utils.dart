import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:strontianite/models/flathub_app_listing_model.dart';
import 'package:strontianite/models/flathub_item_model.dart';

class MarketUtils {
  static const bool installationAvailable = false;

  static Future<List<FlathubItemModel>> getPopularApps() async {
    final uri = Uri.parse('https://flathub.org/api/v2/collection/popular');
    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );
    debugPrint('Response: ${response.body}');
    final List<dynamic> items = jsonDecode(response.body)['hits'];
    final List<FlathubItemModel> apps = [];
    for (final app in items) {
      apps.add(FlathubItemModel.fromJson(app));
    }
    return apps;
  }

  static Future<FlathubAppListingModel> getAppListing(
    FlathubItemModel item,
  ) async {
    final uri = Uri.parse('https://flathub.org/api/v2/appstream/${item.appId}');
    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );
    debugPrint('Listing data: ${response.body}');
    final json = jsonDecode(response.body);
    final listing = FlathubAppListingModel.fromJson(json);
    return listing;
  }


  // Temporary Android implementation.
  // Fedora Flatpak operations will use a future bridge.
  static Future<bool> installApp(
    String id, {
    Function(double percent)? onProgress,
  }) async {
    debugPrint('Flatpak installation is not connected to Fedora yet: $id');
    return false;
  }

  static Future<bool> uninstallApp(
    String id, {
    Function(double percent)? onProgress,
  }) async {
    debugPrint('Flatpak removal is not connected to Fedora yet: $id');
    return false;
  }

  static Future<bool> isInstalled(String id) async {
    return false;
  }

  static Future<List<FlathubItemModel>> searchApps(String query) async {
    if (query.isEmpty) return await getPopularApps();

    final uri = Uri.parse('https://flathub.org/api/v2/search');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'query': query}),
    );
    debugPrint('Response: ${response.body}');
    final List<dynamic> items = jsonDecode(response.body)['hits'] ?? [];
    final List<FlathubItemModel> apps = [];
    for (final app in items) {
      apps.add(FlathubItemModel.fromJson(app));
    }
    return apps;
  }
}
