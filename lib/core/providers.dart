import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/admin_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/booking_repository.dart';
import '../data/repositories/dashboard_repository.dart';
import '../data/repositories/notice_repository.dart';
import '../data/repositories/report_repository.dart';
import '../data/repositories/tariff_repository.dart';
import '../data/services/export_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/receipt_pdf_service.dart';

final supabaseClientProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authRepositoryProvider =
    Provider((ref) => AuthRepository(ref.watch(supabaseClientProvider)));
final noticeRepositoryProvider =
    Provider((ref) => NoticeRepository(ref.watch(supabaseClientProvider)));
final bookingRepositoryProvider =
    Provider((ref) => BookingRepository(ref.watch(supabaseClientProvider)));
final tariffRepositoryProvider =
    Provider((ref) => TariffRepository(ref.watch(supabaseClientProvider)));
final adminRepositoryProvider =
    Provider((ref) => AdminRepository(ref.watch(supabaseClientProvider)));
final dashboardRepositoryProvider =
    Provider((ref) => DashboardRepository(ref.watch(supabaseClientProvider)));
final reportRepositoryProvider =
    Provider((ref) => ReportRepository(ref.watch(supabaseClientProvider)));
final notificationServiceProvider =
    Provider((ref) => NotificationService(ref.watch(supabaseClientProvider)));
final exportServiceProvider = Provider((ref) => ExportService());
final receiptPdfServiceProvider = Provider((ref) => ReceiptPdfService());
