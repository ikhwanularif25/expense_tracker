enum ReportFilter { thisMonth, lastMonth, thisYear }

extension ReportFilterExtension on ReportFilter {
  String get label {
    switch (this) {
      case ReportFilter.thisMonth:
        return 'Bulan Ini';
      case ReportFilter.lastMonth:
        return 'Bulan Lalu';
      case ReportFilter.thisYear:
        return 'Tahun Ini';
    }
  }
}
