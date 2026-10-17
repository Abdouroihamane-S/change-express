import 'dart:convert';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const ConvertisseurApp());

class ConvertisseurApp extends StatelessWidget {
  const ConvertisseurApp({super.key});

  @override
  Widget build(BuildContext context) {
    const graine = Color(0xFF0F9D6B);
    return MaterialApp(
      title: 'Change Express',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: graine,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: graine,
        brightness: Brightness.dark,
      ),
      home: const PageConvertisseur(),
    );
  }
}

// ======================= DONNÉES =======================

class TauxResultat {
  TauxResultat(this.taux, this.miseAJour, this.prochaine);

  final Map<String, double> taux;
  final String miseAJour;
  final String prochaine;
}

Future<TauxResultat> chargerTaux() async {
  final reponse = await http
      .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
      .timeout(const Duration(seconds: 15));

  if (reponse.statusCode != 200) {
    throw Exception('Erreur serveur (${reponse.statusCode})');
  }

  final json = jsonDecode(reponse.body) as Map<String, dynamic>;
  if (json['result'] != 'success') {
    throw Exception('Réponse invalide de l\'API');
  }

  final brut = json['rates'] as Map<String, dynamic>;
  final taux =
      brut.map((cle, valeur) => MapEntry(cle, (valeur as num).toDouble()));

  return TauxResultat(
    taux,
    json['time_last_update_utc']?.toString() ?? '',
    json['time_next_update_utc']?.toString() ?? '',
  );
}

// Une alerte : prévenir quand le taux de->vers passe au-dessus / en dessous
class Alerte {
  Alerte({
    required this.de,
    required this.vers,
    required this.seuil,
    required this.auDessus,
  });

  final String de;
  final String vers;
  final double seuil;
  final bool auDessus;

  bool declenchee(double taux) => auDessus ? taux >= seuil : taux <= seuil;

  Map<String, dynamic> toJson() => {
        'de': de,
        'vers': vers,
        'seuil': seuil,
        'auDessus': auDessus,
      };

  factory Alerte.fromJson(Map<String, dynamic> j) => Alerte(
        de: j['de'] as String,
        vers: j['vers'] as String,
        seuil: (j['seuil'] as num).toDouble(),
        auDessus: j['auDessus'] as bool,
      );
}

class InfoDevise {
  const InfoDevise(this.nom, this.symbole, this.couleur);

  final String nom;
  final String symbole;
  final Color couleur;
}

const Map<String, InfoDevise> infosDevises = {
  'XOF': InfoDevise('Franc CFA (BCEAO)', 'CFA', Color(0xFFF59E0B)),
  'XAF': InfoDevise('Franc CFA (BEAC)', 'CFA', Color(0xFFEA580C)),
  'KMF': InfoDevise('Franc comorien', 'CF', Color(0xFF0891B2)),
  'MRU': InfoDevise('Ouguiya mauritanien', 'UM', Color(0xFF65A30D)),
  'GNF': InfoDevise('Franc guinéen', 'FG', Color(0xFFB45309)),
  'EUR': InfoDevise('Euro', '€', Color(0xFF2563EB)),
  'USD': InfoDevise('Dollar américain', '\$', Color(0xFF16A34A)),
  'GBP': InfoDevise('Livre sterling', '£', Color(0xFF7C3AED)),
  'MAD': InfoDevise('Dirham marocain', 'DH', Color(0xFFDC2626)),
  'NGN': InfoDevise('Naira nigérian', '₦', Color(0xFF059669)),
  'GHS': InfoDevise('Cedi ghanéen', '₵', Color(0xFFCA8A04)),
  'CAD': InfoDevise('Dollar canadien', 'C\$', Color(0xFFE11D48)),
  'CNY': InfoDevise('Yuan chinois', '¥', Color(0xFFB91C1C)),
  'JPY': InfoDevise('Yen japonais', '¥', Color(0xFFBE185D)),
  'CHF': InfoDevise('Franc suisse', 'Fr', Color(0xFF9F1239)),
  'AED': InfoDevise('Dirham des EAU', 'AED', Color(0xFF0F766E)),
  'SAR': InfoDevise('Riyal saoudien', 'SAR', Color(0xFF166534)),
  'DZD': InfoDevise('Dinar algérien', 'DA', Color(0xFF15803D)),
  'TND': InfoDevise('Dinar tunisien', 'DT', Color(0xFFC2410C)),
  'EGP': InfoDevise('Livre égyptienne', 'E£', Color(0xFF4D7C0F)),
  'ZAR': InfoDevise('Rand sud-africain', 'R', Color(0xFF0369A1)),
  'BRL': InfoDevise('Réal brésilien', 'R\$', Color(0xFF047857)),
  'INR': InfoDevise('Roupie indienne', '₹', Color(0xFFF97316)),
  'TRY': InfoDevise('Livre turque', '₺', Color(0xFFEF4444)),
  'RUB': InfoDevise('Rouble russe', '₽', Color(0xFF1E40AF)),
  'MUR': InfoDevise('Roupie mauricienne', 'Rs', Color(0xFF9333EA)),
  'MGA': InfoDevise('Ariary malgache', 'Ar', Color(0xFF0EA5E9)),
};

const List<List<String>> paresPopulaires = [
  ['EUR', 'XOF'],
  ['USD', 'XOF'],
  ['XOF', 'EUR'],
  ['EUR', 'KMF'],
  ['KMF', 'EUR'],
  ['MAD', 'XOF'],
];

// ======================= LOGO DE DEVISE =======================

class BadgeDevise extends StatelessWidget {
  const BadgeDevise({super.key, required this.code, this.taille = 40});

  final String code;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final info = infosDevises[code];
    final base = info?.couleur ?? Colors.blueGrey;
    final clair = Color.lerp(base, Colors.white, 0.3)!;

    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [clair, base],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(taille * 0.18),
        child: FittedBox(
          child: Text(
            info?.symbole ?? code,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

// ======================= FENÊTRE DE CHOIX DE DEVISE =======================

class FeuilleDevises extends StatefulWidget {
  const FeuilleDevises({
    super.key,
    required this.devises,
    required this.selection,
  });

  final List<String> devises;
  final String selection;

  @override
  State<FeuilleDevises> createState() => _FeuilleDevisesState();
}

class _FeuilleDevisesState extends State<FeuilleDevises> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final q = _recherche.toLowerCase().trim();
    final liste = widget.devises.where((code) {
      final nom = infosDevises[code]?.nom.toLowerCase() ?? '';
      return q.isEmpty || code.toLowerCase().contains(q) || nom.contains(q);
    }).toList();

    final media = MediaQuery.of(context);
    final hauteur = (media.size.height - media.viewInsets.bottom) * 0.7;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: hauteur,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Rechercher une devise',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _recherche = v),
              ),
            ),
            Expanded(
              child: liste.isEmpty
                  ? const Center(child: Text('Aucune devise trouvée'))
                  : ListView.builder(
                      itemCount: liste.length,
                      itemBuilder: (context, i) {
                        final code = liste[i];
                        final choisie = code == widget.selection;
                        return ListTile(
                          leading: BadgeDevise(code: code, taille: 40),
                          title: Text(
                            code,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(infosDevises[code]?.nom ?? ''),
                          trailing: choisie
                              ? Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, code),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= ÉCRAN PRINCIPAL =======================

class PageConvertisseur extends StatefulWidget {
  const PageConvertisseur({super.key});

  @override
  State<PageConvertisseur> createState() => _PageConvertisseurState();
}

class _PageConvertisseurState extends State<PageConvertisseur> {
  final TextEditingController _montantCtrl = TextEditingController(text: '100');

  // Onglet Frais : deux services à comparer
  final TextEditingController _fixeA = TextEditingController(text: '2');
  final TextEditingController _pctA = TextEditingController(text: '1');
  final TextEditingController _margeA = TextEditingController(text: '0');
  final TextEditingController _fixeB = TextEditingController(text: '0');
  final TextEditingController _pctB = TextEditingController(text: '0');
  final TextEditingController _margeB = TextEditingController(text: '3');

  // Onglet Alertes : formulaire de création
  final TextEditingController _seuilCtrl = TextEditingController();
  String _alDe = 'EUR';
  String _alVers = 'XOF';
  bool _alAuDessus = true;

  final NumberFormat _fmt0 = NumberFormat.decimalPattern('fr_FR');
  final NumberFormat _fmt2 =
      NumberFormat.decimalPatternDigits(locale: 'fr_FR', decimalDigits: 2);
  final NumberFormat _fmt4 =
      NumberFormat.decimalPatternDigits(locale: 'fr_FR', decimalDigits: 4);

  SharedPreferences? _prefs;

  TauxResultat? _donnees;
  bool _chargement = true;
  String? _erreur;
  bool _bandeauMasque = false;

  int _onglet = 0;
  String _de = 'EUR';
  String _vers = 'XOF';
  double _tours = 0;

  List<String> _cibles = ['XOF', 'USD', 'GBP', 'MAD', 'KMF'];
  List<Alerte> _alertes = [];

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _fixeA.dispose();
    _pctA.dispose();
    _margeA.dispose();
    _fixeB.dispose();
    _pctB.dispose();
    _margeB.dispose();
    _seuilCtrl.dispose();
    super.dispose();
  }

  // ---------- Mémorisation ----------

  Future<void> _demarrer() async {
    await _chargerPrefs();
    await _recharger();
  }

  Future<void> _chargerPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      _de = p.getString('de') ?? _de;
      _vers = p.getString('vers') ?? _vers;
      final montant = p.getString('montant');
      if (montant != null) _montantCtrl.text = montant;
      final cibles = p.getStringList('cibles');
      if (cibles != null) _cibles = List<String>.from(cibles);
      final alertes = p.getStringList('alertes') ?? [];
      _alertes = alertes
          .map((s) => Alerte.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Si le stockage est indisponible, on garde les valeurs par défaut.
    }
  }

  Future<void> _sauver() async {
    final p = _prefs;
    if (p == null) return;
    try {
      await p.setString('de', _de);
      await p.setString('vers', _vers);
      await p.setString('montant', _montantCtrl.text);
      await p.setStringList('cibles', _cibles);
      await p.setStringList(
        'alertes',
        _alertes.map((a) => jsonEncode(a.toJson())).toList(),
      );
    } catch (_) {}
  }

  // setState + sauvegarde
  void _maj(VoidCallback f) {
    setState(f);
    _sauver();
  }

  // ---------- Logique ----------

  Future<void> _recharger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final resultat = await chargerTaux();
      if (!mounted) return;
      setState(() {
        _donnees = resultat;
        _chargement = false;
        _bandeauMasque = false;
        // Sécurité : si une devise mémorisée n'existe plus, on revient au défaut
        if (!resultat.taux.containsKey(_de)) _de = 'EUR';
        if (!resultat.taux.containsKey(_vers)) _vers = 'XOF';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Impossible de récupérer les taux.\nVérifie ta connexion.';
        _chargement = false;
      });
    }
  }

  List<String> _devisesDispo() {
    return infosDevises.keys.where(_donnees!.taux.containsKey).toList();
  }

  Future<String?> _ouvrirChoix(String selection) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FeuilleDevises(
        devises: _devisesDispo(),
        selection: selection,
      ),
    );
  }

  Future<void> _choisir(String courant, void Function(String) appliquer) async {
    final choix = await _ouvrirChoix(courant);
    if (choix == null || !mounted) return;
    _maj(() => appliquer(choix));
  }

  Future<void> _ajouterCible() async {
    final choix = await _ouvrirChoix('');
    if (choix == null || !mounted) return;
    _maj(() {
      if (!_cibles.contains(choix)) _cibles.add(choix);
    });
  }

  void _inverser() {
    _maj(() {
      final temp = _de;
      _de = _vers;
      _vers = temp;
      _tours += 0.5;
    });
  }

  double? _tauxEntre(String de, String vers) {
    final taux = _donnees?.taux;
    if (taux == null || taux[de] == null || taux[vers] == null) return null;
    return taux[vers]! / taux[de]!;
  }

  double? _montant() {
    return double.tryParse(_montantCtrl.text.replaceAll(',', '.'));
  }

  double _num(TextEditingController c) {
    return double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
  }

  // Montant reçu après frais fixes, frais en % et marge sur le taux
  double? _recu(
    double? montant,
    double? taux,
    TextEditingController fixe,
    TextEditingController pct,
    TextEditingController marge,
  ) {
    if (montant == null || taux == null) return null;
    final net = max(0.0, montant - _num(fixe) - montant * _num(pct) / 100);
    return net * taux * (1 - _num(marge) / 100);
  }

  List<(Alerte, double)> _declenchees() {
    final resultat = <(Alerte, double)>[];
    for (final a in _alertes) {
      final t = _tauxEntre(a.de, a.vers);
      if (t != null && a.declenchee(t)) resultat.add((a, t));
    }
    return resultat;
  }

  void _creerAlerte() {
    final seuil = double.tryParse(_seuilCtrl.text.replaceAll(',', '.'));
    if (seuil == null || seuil <= 0 || _alDe == _alVers) {
      _message('Vérifie la paire de devises et le seuil');
      return;
    }
    _maj(() {
      _alertes.add(
        Alerte(de: _alDe, vers: _alVers, seuil: seuil, auDessus: _alAuDessus),
      );
      _bandeauMasque = false;
    });
    _seuilCtrl.clear();
    _message('Alerte créée');
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texte), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _copier(double valeur) async {
    await Clipboard.setData(ClipboardData(text: valeur.toStringAsFixed(2)));
    if (!mounted) return;
    _message('Résultat copié');
  }

  // ---------- Structure générale ----------

  @override
  Widget build(BuildContext context) {
    final pret = !_chargement && _erreur == null && _donnees != null;
    final nbAlertes = pret ? _declenchees().length : 0;

    return Scaffold(
      bottomNavigationBar: pret
          ? NavigationBar(
              selectedIndex: _onglet,
              onDestinationSelected: (i) => setState(() => _onglet = i),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.currency_exchange),
                  label: 'Convertir',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.list_alt),
                  label: 'Multi',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.receipt_long),
                  label: 'Frais',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: nbAlertes > 0,
                    label: Text('$nbAlertes'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  label: 'Alertes',
                ),
              ],
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF12B886), Color(0xFF0A4D3C)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(top: -80, right: -60, child: _cercle(240)),
            Positioned(bottom: -100, left: -80, child: _cercle(300)),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _entete(),
                        const SizedBox(height: 20),
                        _contenu(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenu() {
    if (_chargement) return _vueChargement();
    if (_erreur != null) return _vueErreur();

    final onglet = switch (_onglet) {
      1 => _ongletMulti(),
      2 => _ongletFrais(),
      3 => _ongletAlertes(),
      _ => _ongletConvertir(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_bandeauAlertes(), onglet],
    );
  }

  Widget _cercle(double taille) {
    return Container(
      width: taille,
      height: taille,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white10,
      ),
    );
  }

  Widget _entete() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFB9F6DC)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.currency_exchange,
            color: Color(0xFF0A7A55),
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change Express',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Taux de change du jour',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Actualiser les taux',
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _chargement ? null : _recharger,
        ),
      ],
    );
  }

  Widget _vueChargement() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Chargement des taux...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _vueErreur() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.wifi_off, size: 48),
            const SizedBox(height: 16),
            Text(_erreur!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _recharger, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  // Bandeau affiché au-dessus de tous les onglets quand un seuil est franchi
  Widget _bandeauAlertes() {
    final liste = _declenchees();
    if (liste.isEmpty || _bandeauMasque) return const SizedBox.shrink();

    const texte = Color(0xFF5C4400);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.notifications_active, color: Color(0xFF8A5A00)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alerte de taux',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: texte,
                    ),
                  ),
                  for (final (a, t) in liste)
                    Text(
                      '${a.de} → ${a.vers} : ${_fmt4.format(t)} '
                      '(seuil ${a.auDessus ? '≥' : '≤'} ${_fmt4.format(a.seuil)})',
                      style: const TextStyle(color: texte),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Masquer',
              icon: const Icon(Icons.close, color: texte),
              onPressed: () => setState(() => _bandeauMasque = true),
            ),
          ],
        ),
      ),
    );
  }

  // ======================= ONGLET 1 : CONVERTIR =======================

  Widget _ongletConvertir() {
    final montant = _montant();
    final tauxEntre = _tauxEntre(_de, _vers);
    final resultat =
        (montant != null && tauxEntre != null) ? montant * tauxEntre : null;
    final texteResultat = resultat == null ? '—' : _fmt2.format(resultat);

    final paires = paresPopulaires.where(
      (p) => _donnees!.taux.containsKey(p[0]) && _donnees!.taux.containsKey(p[1]),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: paires.map((p) => _pastillePaire(p[0], p[1])).toList(),
          ),
        ),
        const SizedBox(height: 16),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 24 * (1 - t)),
              child: child,
            ),
          ),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _etiquette('Je convertis'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: _champMontant()),
                      _pilule(_de, () => _choisir(_de, (c) => _de = c)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [10, 100, 1000, 10000].map((valeur) {
                      return ActionChip(
                        label: Text(_fmt0.format(valeur)),
                        onPressed: () => _maj(
                          () => _montantCtrl.text = valeur.toString(),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: IconButton.filledTonal(
                          tooltip: 'Inverser',
                          onPressed: _inverser,
                          icon: AnimatedRotation(
                            turns: _tours,
                            duration: const Duration(milliseconds: 300),
                            child: const Icon(Icons.swap_vert),
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  _etiquette('Je reçois'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Align(
                            key: ValueKey(texteResultat),
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                texteResultat,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (resultat != null)
                        IconButton(
                          tooltip: 'Copier',
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () => _copier(resultat),
                        ),
                      _pilule(_vers, () => _choisir(_vers, (c) => _vers = c)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (tauxEntre != null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BadgeDevise(code: _de, taille: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '1 $_de = ${_fmt4.format(tauxEntre)} $_vers',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                BadgeDevise(code: _vers, taille: 24),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _pied(),
      ],
    );
  }

  // ======================= ONGLET 2 : MULTI =======================

  Widget _ongletMulti() {
    final montant = _montant();
    final cibles = _cibles
        .where((c) => c != _de && _donnees!.taux.containsKey(c))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _carteSource(),
        const SizedBox(height: 16),
        Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                if (cibles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Ajoute une devise avec le bouton ci-dessous'),
                  ),
                for (final code in cibles) _ligneMulti(code, montant),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _ajouterCible,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une devise'),
        ),
        const SizedBox(height: 16),
        _pied(),
      ],
    );
  }

  Widget _ligneMulti(String code, double? montant) {
    final taux = _tauxEntre(_de, code);
    final valeur = (montant != null && taux != null) ? montant * taux : null;

    return ListTile(
      leading: BadgeDevise(code: code, taille: 40),
      title: Text(
        valeur == null ? '—' : '${_fmt2.format(valeur)} $code',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
      ),
      subtitle: Text(infosDevises[code]?.nom ?? code),
      trailing: IconButton(
        tooltip: 'Retirer',
        icon: const Icon(Icons.close),
        onPressed: () => _maj(() => _cibles.remove(code)),
      ),
    );
  }

  // ======================= ONGLET 3 : FRAIS =======================

  Widget _ongletFrais() {
    final montant = _montant();
    final taux = _tauxEntre(_de, _vers);
    final base = (montant != null && taux != null) ? montant * taux : null;

    final recuA = _recu(montant, taux, _fixeA, _pctA, _margeA);
    final recuB = _recu(montant, taux, _fixeB, _pctB, _margeB);

    String? meilleur;
    if (recuA != null && recuB != null && recuA != recuB) {
      meilleur = recuA > recuB ? 'A' : 'B';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _carteSource(destination: true),
        const SizedBox(height: 16),
        _carteService(
            'Service A', _fixeA, _pctA, _margeA, recuA, base, meilleur == 'A'),
        const SizedBox(height: 12),
        _carteService(
            'Service B', _fixeB, _pctB, _margeB, recuB, base, meilleur == 'B'),
        const SizedBox(height: 12),
        const Text(
          'Marge = écart entre le taux du service et le taux du jour. '
          'Elle est souvent cachée dans le taux proposé : compare toujours '
          'le montant final reçu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _pied(),
      ],
    );
  }

  Widget _carteService(
    String titre,
    TextEditingController fixe,
    TextEditingController pct,
    TextEditingController marge,
    double? recu,
    double? base,
    bool meilleur,
  ) {
    final cout = (recu != null && base != null) ? base - recu : null;
    final coutPct =
        (cout != null && base != null && base > 0) ? cout / base * 100 : null;
    final couleurs = Theme.of(context).colorScheme;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titre,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (meilleur)
                  Chip(
                    avatar: Icon(
                      Icons.emoji_events,
                      size: 18,
                      color: couleurs.primary,
                    ),
                    label: const Text('Meilleure offre'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _champ(fixe, 'Fixe ($_de)')),
                const SizedBox(width: 8),
                Expanded(child: _champ(pct, 'Frais %')),
                const SizedBox(width: 8),
                Expanded(child: _champ(marge, 'Marge %')),
              ],
            ),
            const SizedBox(height: 16),
            _etiquette('Le bénéficiaire reçoit'),
            const SizedBox(height: 4),
            Text(
              recu == null ? '—' : '${_fmt2.format(recu)} $_vers',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: couleurs.primary,
              ),
            ),
            if (cout != null && coutPct != null) ...[
              const SizedBox(height: 4),
              Text(
                'Coût total : ${_fmt2.format(cout)} $_vers '
                '(${_fmt2.format(coutPct)} %)',
                style: TextStyle(color: couleurs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ======================= ONGLET 4 : ALERTES =======================

  Widget _ongletAlertes() {
    final couleurs = Theme.of(context).colorScheme;
    final tauxActuel = _tauxEntre(_alDe, _alVers);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nouvelle alerte',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _etiquette('Paire à surveiller'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _pilule(_alDe, () => _choisir(_alDe, (c) => _alDe = c)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 20),
                    ),
                    _pilule(
                      _alVers,
                      () => _choisir(_alVers, (c) => _alVers = c),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _etiquette('Me prévenir quand le taux est'),
                const SizedBox(height: 6),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Au-dessus')),
                    ButtonSegment(value: false, label: Text('En dessous')),
                  ],
                  selected: {_alAuDessus},
                  onSelectionChanged: (s) =>
                      setState(() => _alAuDessus = s.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _seuilCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Seuil',
                    helperText: tauxActuel == null
                        ? null
                        : 'Taux actuel : 1 $_alDe = '
                            '${_fmt4.format(tauxActuel)} $_alVers',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _creerAlerte,
                    icon: const Icon(Icons.add_alert),
                    label: const Text('Créer l\'alerte'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                if (_alertes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Aucune alerte pour le moment',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (var i = 0; i < _alertes.length; i++)
                  _ligneAlerte(i, couleurs),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Les alertes sont vérifiées à l\'ouverture de l\'app et à chaque '
          'actualisation. Les taux n\'étant mis à jour qu\'une fois par jour, '
          'aucune notification n\'est envoyée quand l\'app est fermée.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _pied(),
      ],
    );
  }

  Widget _ligneAlerte(int index, ColorScheme couleurs) {
    final a = _alertes[index];
    final taux = _tauxEntre(a.de, a.vers);
    final declenchee = taux != null && a.declenchee(taux);

    return ListTile(
      leading: Icon(
        declenchee ? Icons.notifications_active : Icons.notifications_none,
        color: declenchee ? Colors.orange : couleurs.onSurfaceVariant,
      ),
      title: Text(
        '${a.de} → ${a.vers}  ${a.auDessus ? '≥' : '≤'}  ${_fmt4.format(a.seuil)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        taux == null
            ? 'Taux indisponible'
            : 'Actuel : ${_fmt4.format(taux)}'
                '${declenchee ? '  ·  seuil atteint' : ''}',
        style: TextStyle(color: declenchee ? Colors.orange.shade800 : null),
      ),
      trailing: IconButton(
        tooltip: 'Supprimer',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _maj(() => _alertes.removeAt(index)),
      ),
    );
  }

  // ======================= COMPOSANTS COMMUNS =======================

  Widget _champMontant() {
    return TextField(
      controller: _montantCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: '0',
      ),
      onChanged: (_) => _maj(() {}),
    );
  }

  Widget _champ(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  // Carte "Montant + devise" des onglets Multi et Frais
  Widget _carteSource({bool destination = false}) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _etiquette(destination ? 'J\'envoie' : 'Montant'),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: _champMontant()),
                _pilule(_de, () => _choisir(_de, (c) => _de = c)),
              ],
            ),
            if (destination) ...[
              const SizedBox(height: 8),
              _etiquette('Vers'),
              const SizedBox(height: 4),
              _pilule(_vers, () => _choisir(_vers, (c) => _vers = c)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pied() {
    final d = _donnees!;
    return Column(
      children: [
        if (d.miseAJour.isNotEmpty)
          Text(
            'Dernière mise à jour : ${d.miseAJour}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        if (d.prochaine.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Prochaine mise à jour : ${d.prochaine}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
        const SizedBox(height: 4),
        const Text(
          'Taux indicatifs fournis par exchangerate-api.com',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _etiquette(String texte) {
    return Text(
      texte,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _pilule(String code, VoidCallback onTap) {
    final couleurs = Theme.of(context).colorScheme;
    return Material(
      color: couleurs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BadgeDevise(code: code, taille: 34),
              const SizedBox(width: 8),
              Text(
                code,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pastillePaire(String de, String vers) {
    final active = de == _de && vers == _vers;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: active ? Colors.white : Colors.white24,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _maj(() {
            _de = de;
            _vers = vers;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              '$de → $vers',
              style: TextStyle(
                color: active ? const Color(0xFF0A4D3C) : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}