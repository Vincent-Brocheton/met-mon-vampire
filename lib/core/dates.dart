/// Dates affichées, sans dépendance à Flutter (utilisables par la logique pure).
const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// « 26 sept. » ; « — » sans date.
String formatDay(DateTime? d) => d == null ? '—' : '${d.day} ${_months[d.month - 1]}';
