import 'dart:convert';
import 'dart:io';

import 'package:flatpak_dart/flatpak_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:strontianite/models/flathub_app_listing_model.dart';
import 'package:strontianite/models/flathub_item_model.dart';
import 'package:http/http.dart' as http;

class MarketUtils {
  static final remote = 'flathub';
  static final _client = FlatpakClient.user();
  static String get _arch {
    final result = Process.runSync('uname', ['-m']);
    final machine = (result.stdout as String).trim();
    return switch (machine) {
      'x86_64' => 'x86_64',
      'aarch64' => 'aarch64',
      'arm64' => 'aarch64',
      _ => machine,
    };
  }

  static String _opChar(String op) => switch (op) {
    'install' => 'i',
    'update' => 'u',
    'uninstall' => 'r',
    _ => '?',
  };

  static String _fmtSize(int n) => n >= 1 << 20
      ? '${(n / (1 << 20)).toStringAsFixed(1)} MB'
      : n >= 1 << 10
      ? '${(n / (1 << 10)).toStringAsFixed(1)} kB'
      : '$n B';

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

  static Future<bool> installApp(
    String id, {
    Function(double percent)? onProgress,
  }) async {
    final ref = 'app/$id/$_arch/stable';
    final tx = _client.install(remote, ref);
    final ops = <String, int>{};
    var opNum = 0;
    final lines = <int, String>{};

    await for (final p in tx.progress) {
      if (!ops.containsKey(p.ref)) {
        opNum++;
        ops[p.ref] = opNum;
      }
      final num = ops[p.ref]!;

      final parts = p.ref.split('/');
      final id = parts.length >= 2 ? parts[1] : p.ref;
      final branch = parts.length >= 4 ? parts[3] : '';

      final done = p.status == 'Done';
      final mark = done ? '\u2713' : ' ';
      final dl = p.bytesTransferred > 0 ? _fmtSize(p.bytesTransferred) : '';

      final line =
          ' $num. [$mark] ${id.padRight(40)} ${branch.padRight(12)} '
          '${_opChar(p.op).padRight(4)} ${remote.padRight(12)} $dl';

      if (lines[num] != line) {
        lines[num] = line;
        for (var i = 1; i <= opNum; i++) {
          stdout.write('\r\x1B[K${lines[i] ?? ""}\n');
        }
        stdout.write('\x1B[${opNum}A');
      }

      if (onProgress != null) {
        onProgress(p.progressPercent / 100);
      }
    }

    stdout.write('\n' * opNum);

    try {
      await tx.result;
      debugPrint('Installation complete.');
    } on FlatpakTransactionException catch (e) {
      if (e.isAlreadyRunning) {
        debugPrint('Another install is in progress. Try again later.');
      } else {
        debugPrint('Installation failed: ${e.message}');
      }
      return false;
    }

    return true;
  }

  static Future<bool> uninstallApp(
    String id, {
    Function(double percent)? onProgress,
  }) async {
    final ref = 'app/$id/$_arch/stable';

    final tx = _client.uninstall(ref);

    final ops = <String, String>{};
    var opNum = 0;

    await for (final p in tx.progress) {
      if (!ops.containsKey(p.ref)) {
        opNum++;
        ops[p.ref] = p.status;
        final parts = p.ref.split('/');
        final id = parts.length >= 2 ? parts[1] : p.ref;
        final branch = parts.length >= 4 ? parts[3] : '';
        final opChar = p.op == 'uninstall' ? '-' : p.op[0];
        debugPrint(' $opNum. [$opChar] ${id.padRight(40)} $branch');
        if (onProgress != null) {
          onProgress(p.progressPercent / 100);
        }
      }
    }

    try {
      await tx.result;
      debugPrint('Uninstall complete.');
    } on FlatpakTransactionException catch (e) {
      debugPrint('Uninstall failed: ${e.message}');
      return false;
    }

    return true;
  }

  static Future<bool> isInstalled(String id) async {
    final apps = await _client.listApplications();
    return apps
        .map((a) {
          final id = a.ref.name;
          debugPrint('App ID: $id');
          return id;
        })
        .contains(id);
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
