import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/core/config/supabase_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SupabaseConfig has valid url and publishableKey configured', () {
    expect(SupabaseConfig.url, equals('https://cntspvnxrmqchvtcdiwv.supabase.co'));
    expect(SupabaseConfig.isConfigured, isTrue);
    expect(SupabaseConfig.publishableKey.startsWith('sb_publishable_'), isTrue);
  });
}
