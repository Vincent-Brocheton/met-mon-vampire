/// Dates affichées, sans dépendance à Flutter (utilisables par la logique pure).
const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// « sept. » pour 9.
String monthAbbr(int month) => _months[month - 1];

/// « 26 sept. » ; « — » sans date.
String formatDay(DateTime? d) => d == null ? '—' : '${d.day} ${_months[d.month - 1]}';
