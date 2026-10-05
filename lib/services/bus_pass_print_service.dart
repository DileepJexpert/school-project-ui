// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../models/transport_models.dart';

/// Handles browser-native printable Student Transport Bus Passes.
class BusPassPrintService {
  static void printBusPass({
    required StudentTransportAssignment assignment,
    required TransportBus bus,
    required TransportRoute? route,
    String schoolName = 'Springdale Public School',
    String academicYear = '2024-2025',
  }) {
    final routeTitle = route?.displayName ?? route?.zoneName ?? 'Standard Transport Route';
    final pickupStop = assignment.pickupStop ?? 'Designated School Stop';
    final pickupTime = route?.firstPickupTime.isNotEmpty == true ? route!.firstPickupTime : '07:15 AM';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Student Bus Pass - ${assignment.studentName}</title>
  <style>
    @media print {
      body { margin: 0; padding: 10px; font-family: 'Segoe UI', Arial, sans-serif; }
      .no-print { display: none; }
      @page { size: auto; margin: 10mm; }
    }
    body { font-family: 'Segoe UI', Arial, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 80vh; background: #f8fafc; }
    .pass-card {
      width: 480px;
      border: 2px solid #17324D;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 4px 14px rgba(0,0,0,0.1);
      background: white;
    }
    .pass-header {
      background: #17324D;
      color: white;
      text-align: center;
      padding: 12px 16px;
    }
    .pass-school { font-size: 16px; font-weight: bold; letter-spacing: 0.5px; text-transform: uppercase; margin: 0; }
    .pass-sub { font-size: 11px; color: #93c5fd; margin-top: 2px; }
    .badge-strip {
      background: #f59e0b;
      color: #172033;
      text-align: center;
      padding: 4px;
      font-size: 12px;
      font-weight: bold;
      letter-spacing: 1px;
      text-transform: uppercase;
    }
    .pass-body {
      padding: 16px 20px;
      display: flex;
      gap: 16px;
    }
    .photo-area {
      width: 90px;
      height: 110px;
      border: 1px dashed #94a3b8;
      border-radius: 6px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 11px;
      color: #64748b;
      text-align: center;
      background: #f1f5f9;
      flex-shrink: 0;
    }
    .details { flex: 1; }
    .student-name { font-size: 17px; font-weight: bold; color: #17324D; margin: 0 0 6px 0; }
    .detail-row { font-size: 12px; margin-bottom: 4px; color: #334155; }
    .detail-row strong { color: #0f172a; }
    .bus-meta-box {
      margin: 12px 20px;
      padding: 10px 14px;
      background: #f8fafc;
      border: 1px solid #cbd5e1;
      border-radius: 8px;
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
      font-size: 12px;
    }
    .bus-meta-item strong { display: block; font-size: 10px; color: #64748b; text-transform: uppercase; }
    .bus-meta-item span { font-weight: bold; color: #17324D; }
    .pass-footer {
      border-top: 1px dashed #cbd5e1;
      padding: 10px 20px 14px;
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
      font-size: 11px;
      color: #64748b;
    }
    .signature-line {
      text-align: center;
      border-top: 1px solid #64748b;
      width: 130px;
      padding-top: 4px;
      font-size: 10px;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <div class="pass-card">
    <div class="pass-header">
      <div class="pass-school">$schoolName</div>
      <div class="pass-sub">Official Student Transport Authority Card · AY $academicYear</div>
    </div>
    <div class="badge-strip">Transport Bus Pass</div>

    <div class="pass-body">
      <div class="photo-area">STUDENT<br>PHOTO</div>
      <div class="details">
        <div class="student-name">${assignment.studentName}</div>
        <div class="detail-row"><strong>Class:</strong> ${assignment.className} ${assignment.rollNumber != null ? '· Roll ${assignment.rollNumber}' : ''}</div>
        <div class="detail-row"><strong>Student ID:</strong> ${assignment.studentId}</div>
        <div class="detail-row"><strong>Route:</strong> $routeTitle</div>
        <div class="detail-row"><strong>Designated Stop:</strong> $pickupStop</div>
      </div>
    </div>

    <div class="bus-meta-box">
      <div class="bus-meta-item">
        <strong>Assigned Bus</strong>
        <span>${bus.busNumber}</span>
      </div>
      <div class="bus-meta-item">
        <strong>First Pickup</strong>
        <span>$pickupTime</span>
      </div>
      <div class="bus-meta-item">
        <strong>Driver Name</strong>
        <span>${bus.driverName}</span>
      </div>
      <div class="bus-meta-item">
        <strong>Emergency Phone</strong>
        <span>${bus.driverMobile}</span>
      </div>
    </div>

    <div class="pass-footer">
      <div>* Must be produced upon boarding vehicle.</div>
      <div class="signature-line">Transport Officer</div>
    </div>
  </div>

  <script>
    window.onload = function() {
      window.print();
    };
  </script>
</body>
</html>
''';

    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }
}
