import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage/json_cache.dart';

/// Di-override di main() setelah SharedPreferences siap.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider di main()'),
);

/// Di-override di main() setelah folder cache dibuka.
final jsonCacheProvider = Provider<JsonCache>(
  (ref) => throw UnimplementedError('Override jsonCacheProvider di main()'),
);
