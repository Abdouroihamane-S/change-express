import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
  TauxResultat(this.taux, this.miseAJour);

  final Map<String, double> taux;
  final String miseAJour;
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

  return TauxResultat(taux, json['time_last_update_utc'] as String);
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
  final NumberFormat _fmt0 = NumberFormat.decimalPattern('fr_FR');
  final NumberFormat _fmt2 =
      NumberFormat.decimalPatternDigits(locale: 'fr_FR', decimalDigits: 2);
  final NumberFormat _fmt4 =
      NumberFormat.decimalPatternDigits(locale: 'fr_FR', decimalDigits: 4);

  TauxResultat? _donnees;
  bool _chargement = true;
  String? _erreur;

  String _de = 'EUR';
  String _vers = 'XOF';
  double _tours = 0;

  @override
  void initState() {
    super.initState();
    _recharger();
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _choisirDevise({required bool source}) async {
    final choix = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FeuilleDevises(
        devises: _devisesDispo(),
        selection: source ? _de : _vers,
      ),
    );
    if (choix == null || !mounted) return;
    setState(() {
      if (source) {
        _de = choix;
      } else {
        _vers = choix;
      }
    });
  }

  void _inverser() {
    setState(() {
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

  Future<void> _copier(double valeur) async {
    await Clipboard.setData(ClipboardData(text: valeur.toStringAsFixed(2)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Résultat copié'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // ---------- Structure générale ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        if (_chargement)
                          _vueChargement()
                        else if (_erreur != null)
                          _vueErreur()
                        else
                          _vueConvertisseur(),
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

  // ---------- Écran principal avec les taux ----------

  Widget _vueConvertisseur() {
    final montant = double.tryParse(_montantCtrl.text.replaceAll(',', '.'));
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
        // Paires populaires
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: paires.map((p) => _pastillePaire(p[0], p[1])).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Carte de conversion
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
                      Expanded(
                        child: TextField(
                          controller: _montantCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '0',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      _pilule(_de, () => _choisirDevise(source: true)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [10, 100, 1000, 10000].map((valeur) {
                      return ActionChip(
                        label: Text(_fmt0.format(valeur)),
                        onPressed: () => setState(
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
                      _pilule(_vers, () => _choisirDevise(source: false)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Taux
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
        Text(
          'Dernière mise à jour : ${_donnees!.miseAJour}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        const Text(
          'Taux indicatifs fournis par exchangerate-api.com',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  // ---------- Petits composants ----------

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
          onTap: () => setState(() {
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