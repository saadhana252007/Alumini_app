/// Permission keys. They mirror the `role_permissions` table in Supabase,
/// where they are enforced by RLS and security-definer functions.
class Perm {
  static const noticeView = 'notice.view';
  static const noticeManage = 'notice.manage';
  static const requestView = 'request.view';
  static const requestCreate = 'request.create';
  static const requestDecide = 'request.decide';
  static const requestManage = 'request.manage';
  static const reportView = 'report.view';
  static const reportExport = 'report.export';
  static const receiptView = 'receipt.view';
  static const paymentSimulate = 'payment.simulate';
  static const tariffManage = 'tariff.manage';
  static const configManage = 'config.manage';
  static const adminManage = 'admin.manage';

  static const all = <String, String>{
    noticeView: 'View notices & posters',
    noticeManage: 'Upload / manage notices',
    requestView: 'View booking requests',
    requestCreate: 'Enter requisitions at the office',
    requestDecide: 'Approve / reject (stage authority)',
    requestManage: 'Cancel / complete bookings',
    reportView: 'View reports & audit logs',
    reportExport: 'Export registers (XLSX/ODS/PDF)',
    receiptView: 'View receipts & payments',
    paymentSimulate: 'Run simulated payment',
    tariffManage: 'Manage tariffs & GST',
    configManage: 'Configure approval workflow',
    adminManage: 'Manage admins & permissions',
  };
}

const roleLabels = <String, String>{
  'edc_admin': 'EDC Admin',
  'dean_admin': 'Dean Admin',
  'super_admin': 'Super Admin',
};

/// Visitor categories as in the EDC form (Section II).
const visitorCategories = <String, String>{
  'A': 'A - Institute guest (free boarding & lodging)',
  'B': 'B - Concession rate (retired faculty/officers, relatives of serving staff)',
  'C': 'C - Official rate (parents/guardian/spouse of students, scholars, alumni)',
  'D': 'D - Full rate (external/official guests, EDP participants, other institutes)',
  'E': 'E - Foreign guests / Chair & Visiting Professors / quarters-entitled staff',
};

const eSubCategories = <String, String>{
  'a': 'E(a) Foreign guest / participant',
  'b': 'E(b) Chair Professor / Visiting Professor (monthly)',
  'c': 'E(c) Employee entitled to quarters (license fee)',
};

const roomTypes = <String, String>{'suite': 'Suite', 'standard': 'Standard Room'};

const billingParties = <String, String>{
  'visitor': 'Visitor',
  'indenter': 'Indenter',
  'department': 'Department',
  'institute': 'Institute',
  'project_coordinator': 'Project Coordinator',
};

const forwardingAuthorities = <String, String>{
  '': 'Not specified',
  'hod': 'HOD',
  'project_coordinator': 'Project Coordinator',
  'dsw': 'DSW (students)',
};

const noticeCategories = <String>[
  'General',
  'Academic',
  'Administrative',
  'Accommodation',
  'Event',
  'Maintenance',
];

const requestStatuses = <String, String>{
  'pending': 'Pending',
  'awaiting_approval': 'Awaiting Approval',
  'approved': 'Approved',
  'rejected': 'Rejected',
  'cancelled': 'Cancelled',
  'completed': 'Completed',
};

const noticeStatuses = <String, String>{
  'draft': 'Draft',
  'published': 'Published',
  'archived': 'Archived',
};
