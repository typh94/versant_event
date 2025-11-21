class PrefillService {
  PrefillService._();
  static final PrefillService instance = PrefillService._();

  Map<String, dynamic>? _salonPrefill;

  void setSalonPrefill(Map<String, dynamic> prefill) {
    _salonPrefill = Map<String, dynamic>.from(prefill);
  }

  /// Returns the stored prefill once and clears it so it is used only one time.
  Map<String, dynamic>? takeSalonPrefill() {
    final tmp = _salonPrefill;
    _salonPrefill = null;
    return tmp == null ? null : Map<String, dynamic>.from(tmp);
  }
}