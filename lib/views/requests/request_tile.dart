import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/booking.dart';

class RequestTile extends StatelessWidget {
  const RequestTile({super.key, required this.request});
  final BookingRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.go('/requests/${r.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(r.reference,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.navy)),
              const Spacer(),
              StatusChip(r.status),
            ]),
            const SizedBox(height: 6),
            Text(r.visitorName,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            if ((r.organization ?? '').isNotEmpty)
              Text(r.organization!,
                  style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 16, runSpacing: 4, children: [
              _meta(Icons.category_outlined, 'Category ${r.categoryLabel}'),
              _meta(Icons.bed_outlined,
                  '${roomTypes[r.roomType]} x${r.numRooms}'),
              _meta(Icons.login, fmtDateTime(r.arrivalAt)),
              _meta(Icons.logout, fmtDateTime(r.departureAt)),
              if (r.allottedRoomNo != null)
                _meta(Icons.meeting_room_outlined, 'Room ${r.allottedRoomNo}'),
              if (r.estimatedAmount != null)
                _meta(Icons.payments_outlined, fmtMoney(r.estimatedAmount)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _meta(IconData i, String t) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 15, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
      ]);
}
