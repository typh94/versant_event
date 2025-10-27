
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, PlatformException;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:docx_template/docx_template.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:versant_event/stubs/open_filex_stub.dart' if (dart.library.io) 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:versant_event/io_stubs.dart' if (dart.library.io) 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'screens/login_page.dart';
import 'screens/drafts_list_screen.dart';
import 'package:ionicons/ionicons.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'widgets/io_image.dart';

import 'package:versant_event/stubs/flutter_email_sender_stub.dart' if (dart.library.io) 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:printing/printing.dart';
import 'screens/pdf_preview_screen.dart';
import 'dart:convert';

import 'constants/app_colors.dart';
import 'models/sub_photo_entry.dart';
import 'widgets/sub_photo_dialog.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final loggedIn = await AuthService.isLoggedIn();
  runApp(MaterialApp(
    home: loggedIn ? HomePage() : LoginScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

// HomePage
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Déconnexion'),
        content: Text('Voulez-vous vraiment vous déconnecter?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: bleuAmont)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Déconnexion', style: TextStyle(color: roseVE)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     // backgroundColor: Colors.white10,
      // backgroundColor: Color(0xFF1A1A1A),
       backgroundColor: Colors.white,

      appBar: AppBar(
        title: Text('Versant Event'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
             // child: Text(
             //   _userName,
             //   style: TextStyle(fontWeight: FontWeight.bold),
            //  ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            SizedBox(height: 20),

            // Nouvelle Fiche Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FormToWordPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                  textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  backgroundColor: roseVE
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outlined, size: 22, color: blanc ),
                  SizedBox(width: 8),
                  Text('Nouveau Rapport de Vérification', style: TextStyle(color: blanc)),

                ],
              ),
            ),

            SizedBox(height: 12),

            // Toutes mes fiches Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DraftsListScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                backgroundColor: Colors.white24,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open, size: 22, color: blanc),
                  SizedBox(width: 8),
                  Text('Tous mes Rapports', style: TextStyle(color: blanc)),
                ],
              ),
            ),

            SizedBox(height: 20),




            SizedBox(height: 400),

            // Logout Button
            ElevatedButton(
              onPressed: _handleLogout,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.redAccent,
                padding: EdgeInsets.symmetric(vertical: 6),
                textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              child: Text('Déconnexion'),
            ),
          ],
        ),
      ),
    );
  }


}


class FormToWordPage extends StatefulWidget {
  @override
  _FormToWordPageState createState() => _FormToWordPageState();
}

class _FormToWordPageState extends State<FormToWordPage> {
  String _currentUsername = '';
  // Keeps the path of the last generated DOCX to attach/share it by email
  String _lastGeneratedDocPath = '';
  // Keeps the path of the last generated PDF to attach/share it by email
  String _lastGeneratedPdfPath = '';
  int nbTableaux = 0;

    @override
    void initState() {
      super.initState();
      AuthService.currentUsername().then((u) {
        if (mounted) setState(() => _currentUsername = u ?? '');
      });
    }

  // Signature
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  String _signaturePath = '';
  Uint8List? _signatureBytes; // Web: store signature bytes in memory
  Uint8List? _lastGeneratedPdfBytes; // Web: keep generated PDF in memory for preview

 // List<bool?> checkboxValues = List.generate(14, (_) => null);
  Map<int, String?> checkboxValues2 = {};

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  int _currentPage = 0;
  final PageController _pageController = PageController();
  final ImagePicker _picker = ImagePicker();

  // Page 1 controllers
  final _nosReferences = TextEditingController();
  final _clientFacture = TextEditingController();
  final _contactFacture = TextEditingController();
  final _addresseFacture = TextEditingController();
  final _telFacture = TextEditingController();
  final _emailFacture = TextEditingController();
  final _refFacture = TextEditingController();
  final _contactSinistre = TextEditingController();
  final _addresseSinistre = TextEditingController();
  final _telSinistre = TextEditingController();
  final _emailSinistre = TextEditingController();
  final _contexteIntervention = TextEditingController();
  final _infoAcces = TextEditingController();
  final _etatDemande = TextEditingController();
  final _startTime = TextEditingController();
  final _endTime = TextEditingController();
  final _date = TextEditingController();


  //
  final _techName = TextEditingController();
  final _localAdress = TextEditingController(text: "12 rue des frères lumières Lumière 77290 MITRY MORY");
  final _localTel = TextEditingController(text: "01 46 38 58 71");
  final _localMail = TextEditingController(text: "contact@versantevenement.com");
  final _doName = TextEditingController(text:"TBD");
  final _objMission = TextEditingController();
  final _pageNumber = TextEditingController();
  final _dateTransmission = TextEditingController();

  final _standName = TextEditingController();
  final _standHall = TextEditingController();
  final _standNb = TextEditingController();
  final _salonName = TextEditingController(text: "FIE");
  final _siteName = TextEditingController(text: "PORTE DE VERSAILLES");
  final _siteAdress = TextEditingController(text: "1 Place de la porte de Versailles 75015 PARIS");
  final _standDscrptn = TextEditingController();
  final _dateMontage = TextEditingController(text: "DATE");
  final _dateEvnmt = TextEditingController(text: "02/12/25 au 04/12/25");
  final _catErpType = TextEditingController(text: "T");
  final _effectifMax = TextEditingController(text: "TBD");

  final _orgaName = TextEditingController(text: "ORGA");
  final _installateurName = TextEditingController();
  final _exploitSiteName = TextEditingController(text: "VIPARIS");
  final _proprioMatosName = TextEditingController();


  final _nbStructures = TextEditingController();
  final _nbTableauxBesoin = TextEditingController();
  final _hauteur = TextEditingController();
  // Per-gril controllers for independent values
  List<TextEditingController> _hauteurCtrls = [];
  List<TextEditingController> _ouvertureCtrls = [];
  List<TextEditingController> _profondeurCtrls = [];
  List<TextEditingController> _nbTowerCtrls = [];
  List<TextEditingController> _nbPalansCtrls = [];
  List<TextEditingController> _marqueModelPPCtrls = [];
  List<TextEditingController> _rideauxEnseignesCtrls = [];
  List<TextEditingController> _poidGrilTotalCtrls = [];

  void _ensureGrilControllersLength(int count) {
    void grow(List<TextEditingController> list) {
      while (list.length < count) list.add(TextEditingController());
      if (list.length > count) {
        // Dispose extra controllers
        for (var c in list.sublist(count)) c.dispose();
        list.removeRange(count, list.length);
      }
    }
    grow(_hauteurCtrls);
    grow(_ouvertureCtrls);
    grow(_profondeurCtrls);
    grow(_nbTowerCtrls);
    grow(_nbPalansCtrls);
    grow(_marqueModelPPCtrls);
    grow(_rideauxEnseignesCtrls);
    grow(_poidGrilTotalCtrls);
  }

  String _joinGrilValues(List<TextEditingController> ctrls) {
    if (ctrls.isEmpty) return '';
    return List.generate(ctrls.length, (i) => 'Gril ${i + 1}: ${ctrls[i].text.trim()}').join('\n');
  }

  String _grilValueForExport(List<TextEditingController> ctrls, TextEditingController single) {
    final joined = _joinGrilValues(ctrls);
    if (joined.isNotEmpty) return joined;
    return single.text.trim();
  }
  final _ouverture = TextEditingController();
  final _profondeur = TextEditingController();
  final _nbTower = TextEditingController();
  final _nbPalans = TextEditingController();
  final _marqueModelPP = TextEditingController();
  final _rideauxEnseignes = TextEditingController();
  final _poidGrilTotal = TextEditingController();

  final _windSpeed = TextEditingController(text: "30 Km/heure");
  final _docConsultName= TextEditingController();
  final _docConsultResp= TextEditingController();


  final _question1 = TextEditingController(); // Notice technique
  final _question2 = TextEditingController(); // Plans de détail
  final _question3 = TextEditingController(); // Notes de calculs
  final _question4 = TextEditingController(); // Abaques de charges
  final _question5 = TextEditingController(); // Avis sur modele
  final _question6 = TextEditingController(); // avis dossier technique
  final _question7 = TextEditingController(); // etude du sol
  final _question8 = TextEditingController(); // avis solidite
  final _question9 = TextEditingController(); // capacite portante
  final _question10 = TextEditingController(); // pv de classement
  final _question11 = TextEditingController(); // attestatioon de bon montage
  final _question12 = TextEditingController(); // dossier de securite
  final _question13 = TextEditingController(); // vgp des palans


  final _article3 = TextEditingController();
  final _article5 = TextEditingController();
  final _article6 = TextEditingController();
  final _article7 = TextEditingController();
  final _article9 = TextEditingController();
  final _article10 = TextEditingController();
  final _article11 = TextEditingController();
  final _article12 = TextEditingController();
  final _article13 = TextEditingController();
  final _article14 = TextEditingController();
  final _article15 = TextEditingController();
  final _article16 = TextEditingController();
  final _article17 = TextEditingController();
  final _article18 = TextEditingController();
  final _article19 = TextEditingController();
  final _article20 = TextEditingController();
  final _article21 = TextEditingController();
  final _article22 = TextEditingController();
  final _article23 = TextEditingController();
  final _article24 = TextEditingController();
  final _article25 = TextEditingController();
  final _article26 = TextEditingController();
  final _article27 = TextEditingController();
  final _article28 = TextEditingController();
  final _article29 = TextEditingController();
  final _article30 = TextEditingController();
  final _article31 = TextEditingController();
  final _article32 = TextEditingController();
  final _article33 = TextEditingController();
  final _article34 = TextEditingController();
  final _article36 = TextEditingController();
  final _article37 = TextEditingController();
  final _article38 = TextEditingController();
  final _article39 = TextEditingController();
  final _article45 = TextEditingController();
  final _article47 = TextEditingController();
  final _article48 = TextEditingController();



  Map<int, bool?> checkboxValues = {
    1: null,
    2: null,
    3: null,
    4: null,
    5: null,
    6: null,
    7: null,
    8: null,
    9: null,
    10: null,
    11: null,
    12: null,
    13: null,
  };




  final _article3Response = TextEditingController();
  final _article3Obsrvt = TextEditingController();
  final _article3Photo = TextEditingController();
  final _article5Obsrvt = TextEditingController();
  final _article6Obsrvt = TextEditingController();
  final _article7Obsrvt = TextEditingController();
  final _article9Obsrvt = TextEditingController();
  final _article10Obsrvt = TextEditingController();
  final _article11Obsrvt = TextEditingController();
  final _article12Obsrvt = TextEditingController();
  final _article13Obsrvt = TextEditingController();
  final _article14Obsrvt = TextEditingController();
  final _article15Obsrvt = TextEditingController();
  final _article16Obsrvt = TextEditingController();
  final _article17Obsrvt = TextEditingController();
  final _article18Obsrvt = TextEditingController();
  final _article19Obsrvt = TextEditingController();
  final _article20Obsrvt = TextEditingController();
  final _article21Obsrvt = TextEditingController();
  final _article22Obsrvt = TextEditingController();
  final _article23Obsrvt = TextEditingController();
  final _article24Obsrvt = TextEditingController();
  final _article25Obsrvt = TextEditingController();
  final _article26Obsrvt = TextEditingController();
  final _article27Obsrvt = TextEditingController();
  final _article28Obsrvt = TextEditingController();
  final _article29Obsrvt = TextEditingController();
  final _article30Obsrvt = TextEditingController();
  final _article31bsrvt = TextEditingController();
  final _article32bsrvt = TextEditingController();
  final _article33bsrvt = TextEditingController();
  final _article34bsrvt = TextEditingController();
  final _article36bsrvt = TextEditingController();
  final _article37bsrvt = TextEditingController();
  final _article38bsrvt = TextEditingController();
  final _article39bsrvt = TextEditingController();
  final _article45bsrvt = TextEditingController();
  final _article47bsrvt = TextEditingController();
  final _article48bsrvt = TextEditingController();

  final _avisFav = TextEditingController();
  final _avisDefav = TextEditingController();

final _mailStand = TextEditingController();


  // Draft support
  String? _draftId;
  bool _draftApplied = false;

  Map<String, dynamic> _toDraftJson() {
    return {
      'title': _nosReferences.text,
      'owner': _currentUsername,
      'nosReferences': _nosReferences.text,
      'clientFacture': _clientFacture.text,
      'contactFacture': _contactFacture.text,
      'addresseFacture': _addresseFacture.text,
      'telFacture': _telFacture.text,
      'emailFacture': _emailFacture.text,
      'refFacture': _refFacture.text,
      'contactSinistre': _contactSinistre.text,
      'addresseSinistre': _addresseSinistre.text,
      'telSinistre': _telSinistre.text,
      'emailSinistre': _emailSinistre.text,
      'contexteIntervention': _contexteIntervention.text,
      'infoAcces': _infoAcces.text,
      'etatDemande': _etatDemande.text,
      'startTime': _startTime.text,
      'endTime': _endTime.text,
      'date': _date.text,
      'textConclusion': _textConclusion.text,
      'textPreconisations': _textPreconisations.text,
      'buildingPhotoPath': _buildingPhotoPath,
            // Persist signature as base64-encoded PNG bytes (web-safe)
            'signaturePng': (() {
              try {
                if (_signatureBytes != null && _signatureBytes!.isNotEmpty) {
                  return base64Encode(_signatureBytes!);
                } else if (_signaturePath.isNotEmpty) {
                  final f = File(_signaturePath);
                  if (f.existsSync()) {
                    final bytes = f.readAsBytesSync();
                    return base64Encode(bytes);
                  }
                }
              } catch (_) {}
              return null; // keep missing if no signature
            })(),

      // Minimal persistence for "Renseignements concernant l'ensemble démontable" (grils)
      'nbTableaux': nbTableaux,
      'grilsHauteur': _hauteurCtrls.map((c) => c.text).toList(),
      'grilsOuverture': _ouvertureCtrls.map((c) => c.text).toList(),
      'grilsProfondeur': _profondeurCtrls.map((c) => c.text).toList(),

      'nbTowers': _nbTowerCtrls.map((c) => c.text).toList(),
      'nbPalans': _nbPalansCtrls.map((c) => c.text).toList(),
      'marqueModelPP': _marqueModelPPCtrls.map((c) => c.text).toList(),
      'rideauxEnseignes': _rideauxEnseignesCtrls.map((c) => c.text).toList(),
      'poidGrilTot': _poidGrilTotalCtrls.map((c) => c.text).toList(),

    // Minimal persistence for "Documents consultés" (first 3 only)
      'docsConsultes': {
        '1': {
          'status': checkboxValues[1],
          'comment': _question1.text,
        },
        '2': {
          'status': checkboxValues[2],
          'comment': _question2.text,
        },
        '3': {
          'status': checkboxValues[3],
          'comment': _question3.text,
        },
        '4': {
          'status': checkboxValues[4],
          'comment': _question3.text,
        },
        '5': {
          'status': checkboxValues[5],
          'comment': _question3.text,
        },
        '6': {
          'status': checkboxValues[6],
          'comment': _question3.text,
        },
        '7': {
          'status': checkboxValues[7],
          'comment': _question3.text,
        },
        '8': {
          'status': checkboxValues[8],
          'comment': _question3.text,
        },
        '9': {
          'status': checkboxValues[9],
          'comment': _question3.text,
        },
        '10': {
          'status': checkboxValues[10],
          'comment': _question3.text,
        },
        '11': {
          'status': checkboxValues[11],
          'comment': _question3.text,
        },
        '12': {
          'status': checkboxValues[12],
          'comment': _question3.text,
        },
        '13': {
          'status': checkboxValues[13],
          'comment': _question3.text,
        },

      },

      //  "Tableau des vérifications"
      'verifications': {
        '3': {
          'status': checkboxValues2[3],
          'obs': _article3Obsrvt.text,
          'photoPath': _articlePhotos[3]?.imagePath,
        }, 
        '5': {
          'status': checkboxValues2[5],
          'obs': _article5Obsrvt.text,
          'photoPath': _articlePhotos[5]?.imagePath,
        },
        '6': {
          'status': checkboxValues2[6],
          'obs': _article6Obsrvt.text,
          'photoPath': _articlePhotos[6]?.imagePath,
        },

        '7': {
          'status': checkboxValues2[7],
          'obs': _article7Obsrvt.text,
          'photoPath': _articlePhotos[7]?.imagePath,

        },
        '9': {
          'status': checkboxValues2[9],
          'obs': _article9Obsrvt.text,
          'photoPath': _articlePhotos[9]?.imagePath,

        },
        '10': {
          'status': checkboxValues2[10],
          'obs': _article10Obsrvt.text,
          'photoPath': _articlePhotos[10]?.imagePath,

        },
        '11': {
          'status': checkboxValues2[11],
          'obs': _article11Obsrvt.text,
          'photoPath': _articlePhotos[11]?.imagePath,

        },
        '12': {
          'status': checkboxValues2[12],
          'obs': _article12Obsrvt.text,
          'photoPath': _articlePhotos[12]?.imagePath,

        },
        '13': {
          'status': checkboxValues2[13],
          'obs': _article13Obsrvt.text,
          'photoPath': _articlePhotos[13]?.imagePath,

        },
        '14': {
          'status': checkboxValues2[14],
          'obs': _article14Obsrvt.text,
          'photoPath': _articlePhotos[14]?.imagePath,
        },

        '15': {
          'status': checkboxValues2[15],
          'obs': _article15Obsrvt.text,
          'photoPath': _articlePhotos[15]?.imagePath,

        },
        '16': {
          'status': checkboxValues2[16],
          'obs': _article16Obsrvt.text,
          'photoPath': _articlePhotos[16]?.imagePath,

        },
        '17': {
          'status': checkboxValues2[17],
          'obs': _article17Obsrvt.text,
          'photoPath': _articlePhotos[17]?.imagePath,

        },
        '18': {
          'status': checkboxValues2[18],
          'obs': _article18Obsrvt.text,
          'photoPath': _articlePhotos[18]?.imagePath,

        },
        '19': {
          'status': checkboxValues2[19],
          'obs': _article19Obsrvt.text,
          'photoPath': _articlePhotos[19]?.imagePath,

        },
        '20': {
          'status': checkboxValues2[20],
          'obs': _article20Obsrvt.text,
          'photoPath': _articlePhotos[20]?.imagePath,

        },
        '21': {
          'status': checkboxValues2[21],
          'obs': _article21Obsrvt.text,
          'photoPath': _articlePhotos[21]?.imagePath,

        },
        '22': {
          'status': checkboxValues2[22],
          'obs': _article22Obsrvt.text,
          'photoPath': _articlePhotos[22]?.imagePath,

        },
        '23': {
          'status': checkboxValues2[23],
          'obs': _article23Obsrvt.text,
          'photoPath': _articlePhotos[23]?.imagePath,

        },
        '24': {
          'status': checkboxValues2[24],
          'obs': _article24Obsrvt.text,
          'photoPath': _articlePhotos[24]?.imagePath,

        },
        '25': {
          'status': checkboxValues2[25],
          'obs': _article25Obsrvt.text,
          'photoPath': _articlePhotos[25]?.imagePath,

        },
        '26': {
          'status': checkboxValues2[26],
          'obs': _article26Obsrvt.text,
          'photoPath': _articlePhotos[26]?.imagePath,

        },
        '27': {
          'status': checkboxValues2[27],
          'obs': _article27Obsrvt.text,
          'photoPath': _articlePhotos[27]?.imagePath,

        },
        '28': {
          'status': checkboxValues2[28],
          'obs': _article28Obsrvt.text,
          'photoPath': _articlePhotos[28]?.imagePath,

        },
        '29': {
          'status': checkboxValues2[29],
          'obs': _article29Obsrvt.text,
          'photoPath': _articlePhotos[29]?.imagePath,

        },
        '30': {
          'status': checkboxValues2[30],
          'obs': _article30Obsrvt.text,
          'photoPath': _articlePhotos[30]?.imagePath,

        },
        '31': {
          'status': checkboxValues2[31],
          'obs': _article31bsrvt.text,
          'photoPath': _articlePhotos[31]?.imagePath,

        },
        '32': {
          'status': checkboxValues2[32],
          'obs': _article32bsrvt.text,
          'photoPath': _articlePhotos[32]?.imagePath,

        },
        '33': {
          'status': checkboxValues2[33],
          'obs': _article33bsrvt.text,
          'photoPath': _articlePhotos[33]?.imagePath,

        },
        '34': {
          'status': checkboxValues2[34],
          'obs': _article34bsrvt.text,
          'photoPath': _articlePhotos[34]?.imagePath,

        },
        '36': {
          'status': checkboxValues2[36],
          'obs': _article36bsrvt.text,
          'photoPath': _articlePhotos[36]?.imagePath,

        },
        '37': {
          'status': checkboxValues2[37],
          'obs': _article37bsrvt.text,
          'photoPath': _articlePhotos[37]?.imagePath,

        },
        '38': {
          'status': checkboxValues2[38],
          'obs': _article38bsrvt.text,
          'photoPath': _articlePhotos[38]?.imagePath,

        },
        '39': {
          'status': checkboxValues2[39],
          'obs': _article39bsrvt.text,
          'photoPath': _articlePhotos[39]?.imagePath,

        },
        '45': {
          'status': checkboxValues2[45],
          'obs': _article45bsrvt.text,
          'photoPath': _articlePhotos[45]?.imagePath,

        },
        '47': {
          'status': checkboxValues2[47],
          'obs': _article47bsrvt.text,
          'photoPath': _articlePhotos[47]?.imagePath,

        },
        '48': {
          'status': checkboxValues2[48],
          'obs': _article48bsrvt.text,
          'photoPath': _articlePhotos[48]?.imagePath,

        },

      },

      'hall': _standHall.text,
      'standName': _standName.text,
      'standNb': _standNb.text,

      'techName': _techName.text,
      'localAdress':  _localAdress.text,
      'dateTransmission': _dateTransmission.text,

      'localTel': _localTel.text,
      'localMail': _localMail.text,
      'doName': _doName.text,
      'objMission': _objMission.text,
      'salonName': _salonName.text,

      'installateurName': _installateurName.text,
      'proprioMatosName': _proprioMatosName.text,
      'nbStructuresTot': _nbStructures.text,

      'mailClient': _mailStand.text,
      'dscrptnSommaire' : _standDscrptn.text,
      'subPhotos': _subPhotos
          .map((e) => {
            'number': e.number,
            'description': e.description,
            'imagePath': e.imagePath,
          })
          .toList(),
    };
  }

  void _loadFromDraftJson(Map<String, dynamic> json) {
    // Restore minimal subsets requested: grils (3 fields), documents consultés (3), vérifications (3)
    // Per-gril fields
    final int savedNbTableaux = (json['nbTableaux'] ?? 0) is int
        ? (json['nbTableaux'] as int)
        : int.tryParse((json['nbTableaux'] ?? '0').toString()) ?? 0;
    if (savedNbTableaux > 0) {
      nbTableaux = savedNbTableaux;
      _nbTableauxBesoin.text = savedNbTableaux.toString();
      _ensureGrilControllersLength(nbTableaux);
      List grH = (json['grilsHauteur'] ?? []) as List;
      List grO = (json['grilsOuverture'] ?? []) as List;
      List grP = (json['grilsProfondeur'] ?? []) as List;

      List grT = (json['nbTowers'] ?? []) as List;
      List grPa = (json['nbPalans'] ?? []) as List;
      List grMPP = (json['marqueModelPP'] ?? []) as List;
      List grE = (json['rideauxEnseignes'] ?? []) as List;
      List grTot = (json['poidGrilTot'] ?? []) as List;

      for (int i = 0; i < nbTableaux; i++) {
        if (i < grH.length) _hauteurCtrls[i].text = (grH[i] ?? '').toString();
        if (i < grO.length) _ouvertureCtrls[i].text = (grO[i] ?? '').toString();
        if (i < grP.length) _profondeurCtrls[i].text = (grP[i] ?? '').toString();

        if (i < grT.length) _nbTowerCtrls[i].text = (grT[i] ?? '').toString();
        if (i < grPa.length) _nbPalansCtrls[i].text = (grPa[i] ?? '').toString();
        if (i < grMPP.length) _marqueModelPPCtrls[i].text = (grMPP[i] ?? '').toString();
        if (i < grE.length) _rideauxEnseignesCtrls[i].text = (grE[i] ?? '').toString();
        if (i < grTot.length) _poidGrilTotalCtrls[i].text = (grTot[i] ?? '').toString();

      }
    }

    // Documents consultés (first 3 items: status + comment)
    final docs = json['docsConsultes'];
    if (docs is Map) {
      for (final k in ['1','2','3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13']) {
        final item = docs[k];
        if (item is Map) {
          checkboxValues[int.parse(k)] = item['status'] as bool?;
          final comment = (item['comment'] ?? '') as String;
          switch (k) {
            case '1': _question1.text = comment; break;
            case '2': _question2.text = comment; break;
            case '3': _question3.text = comment; break;
            case '4': _question4.text = comment; break;
            case '5': _question5.text = comment; break;
            case '6': _question6.text = comment; break;
            case '7': _question7.text = comment; break;
            case '8': _question8.text = comment; break;
            case '9': _question9.text = comment; break;
            case '10': _question10.text = comment; break;
            case '11': _question11.text = comment; break;
            case '12': _question12.text = comment; break;
            case '13': _question13.text = comment; break;
          }
        }
      }
    }

    // Tableau des vérifications (3, 5, 6: status string S/NS/SO + observation)
    final verif = json['verifications'];
    if (verif is Map) {
      for (final k in ['3','5','6', '7', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21'
                      , '22', '23', '24', '25', '26', '27', '28', '29', '30', '31', '32', '33', '34', '36', '37', '38', '39', '45', '47', '48' ]) {
        final item = verif[k];
        if (item is Map) {
          checkboxValues2[int.parse(k)] = (item['status'] as String?);
          final obs = (item['obs'] ?? '') as String;
          // Restore photoPath for selected articles (3,5,6)
          final photoPath = (item['photoPath'] ?? '') as String;
          if (photoPath.isNotEmpty && ['3','5','6'].contains(k)) {
            final idx = int.parse(k);
            _articlePhotos[idx] = SubPhotoEntry(
              number: '0',
              description: obs.isNotEmpty ? obs : 'Article $k',
              imagePath: photoPath,
            );
          }
          switch (k) {
            case '3': _article3Obsrvt.text = obs; break;
            case '5': _article5Obsrvt.text = obs; break;
            case '6': _article6Obsrvt.text = obs; break;
            case '7': _article7Obsrvt.text = obs; break;
            case '9': _article9Obsrvt.text = obs; break;
            case '10': _article10Obsrvt.text = obs; break;
            case '11': _article11Obsrvt.text = obs; break;
            case '12': _article12Obsrvt.text = obs; break;
            case '13': _article13Obsrvt.text = obs; break;
            case '14': _article14Obsrvt.text = obs; break;
            case '15': _article15Obsrvt.text = obs; break;
            case '16': _article16Obsrvt.text = obs; break;
            case '17': _article17Obsrvt.text = obs; break;
            case '18': _article18Obsrvt.text = obs; break;
            case '19': _article19Obsrvt.text = obs; break;
            case '20': _article20Obsrvt.text = obs; break;
            case '21': _article21Obsrvt.text = obs; break;
            case '22': _article22Obsrvt.text = obs; break;
            case '23': _article23Obsrvt.text = obs; break;
            case '24': _article24Obsrvt.text = obs; break;
            case '25': _article25Obsrvt.text = obs; break;
            case '26': _article26Obsrvt.text = obs; break;
            case '27': _article27Obsrvt.text = obs; break;
            case '28': _article28Obsrvt.text = obs; break;
            case '29': _article29Obsrvt.text = obs; break;
            case '30': _article30Obsrvt.text = obs; break;
            case '31': _article31bsrvt.text = obs; break;
            case '32': _article32bsrvt.text = obs; break;
            case '33': _article33bsrvt.text = obs; break;
            case '34': _article34bsrvt.text = obs; break;
            case '36': _article36bsrvt.text = obs; break;
            case '37': _article37bsrvt.text = obs; break;
            case '38': _article38bsrvt.text = obs; break;
            case '39': _article39bsrvt.text = obs; break;
            case '45': _article45bsrvt.text = obs; break;
            case '47': _article47bsrvt.text = obs; break;
            case '48': _article48bsrvt.text = obs; break;

          }
        }
      }
    }

    // Restore signature from base64 if present
    final sigB64 = json['signaturePng'];
    if (sigB64 is String && sigB64.isNotEmpty) {
      try {
        _signatureBytes = base64Decode(sigB64);
        _signaturePath = '';
      } catch (_) {}
    }

    _standHall.text = (json['hall'] ?? '') as String;
    _standName.text = (json['standName'] ?? '') as String;
    _techName.text = (json['techName'] ?? '') as String;
    _localAdress.text = (json['localAdress'] ?? '') as String;
    _dateTransmission.text = (json['dateTransmission'] ?? '') as String;
    _objMission.text = (json['objMission'] ?? '') as String;
    _standNb.text = (json['standNb'] ?? '') as String;
    _localTel.text= (json['localTel'] ?? '') as String;
    _localMail.text= (json['localMail'] ?? '') as String;
    _doName.text= (json['doName'] ?? '') as String;
    _salonName.text= (json['salonName'] ?? '') as String;
    _mailStand.text= (json['mailClient'] ?? '') as String;
    _standDscrptn.text= (json['dscrptnSommaire'] ?? '') as String;

    _nosReferences.text = (json['nosReferences'] ?? '') as String;
    _clientFacture.text = (json['clientFacture'] ?? '') as String;
    _contactFacture.text = (json['contactFacture'] ?? '') as String;
    _addresseFacture.text = (json['addresseFacture'] ?? '') as String;
    _telFacture.text = (json['telFacture'] ?? '') as String;
    _emailFacture.text = (json['emailFacture'] ?? '') as String;
    _refFacture.text = (json['refFacture'] ?? '') as String;
    _contactSinistre.text = (json['contactSinistre'] ?? '') as String;
    _addresseSinistre.text = (json['addresseSinistre'] ?? '') as String;
    _telSinistre.text = (json['telSinistre'] ?? '') as String;
    _emailSinistre.text = (json['emailSinistre'] ?? '') as String;
    _contexteIntervention.text = (json['contexteIntervention'] ?? '') as String;
    _infoAcces.text = (json['infoAcces'] ?? '') as String;
    _etatDemande.text = (json['etatDemande'] ?? '') as String;
    _startTime.text = (json['startTime'] ?? '') as String;
    _endTime.text = (json['endTime'] ?? '') as String;
    _date.text = (json['date'] ?? '') as String;
    _textConclusion.text = (json['textConclusion'] ?? '') as String;
    _textPreconisations.text = (json['textPreconisations'] ?? '') as String;
    _buildingPhotoPath = (json['buildingPhotoPath'] ?? '') as String;

    _installateurName.text = (json['installateurName'] ?? '') as String;
    _proprioMatosName.text = (json['proprioMatosName'] ?? '') as String;
    _nbStructures.text = (json['nbStructuresTot'] ?? '') as String;

    /*
    _nbTowerCtrls.text = (json['nbTowers'] ?? '') as String;
    _nbPalansCtrls.text = (json['nbPalans'] ?? '') as String;
    _marqueModelPPCtrls.text = (json['marqueModelPP'] ?? '') as String;
    _rideauxEnseignesCtrls.text = (json['rideauxEnseignes'] ?? '') as String;
    _poidGrilTotalCtrls.text = (json['poidGrilTot'] ?? '') as String;
*/


    final sub = json['subPhotos'];
    _subPhotos = [];
    if (sub is List) {
      for (final item in sub) {
        if (item is Map<String, dynamic>) {
          _subPhotos.add(SubPhotoEntry(
            number: (item['number'] ?? '').toString(),
            description: (item['description'] ?? '').toString(),
            imagePath: (item['imagePath'] ?? '').toString(),
          ));
        }
      }
    }
  }

  // Page 2 controllers
  final _textConclusion = TextEditingController();
  final _textPreconisations = TextEditingController();


  // Building photo
  String _buildingPhotoPath = '';

  // Sub-photo entries
  List<SubPhotoEntry> _subPhotos = [];

  // Per-article photos (example: we wire 3, 5, 7; extend similarly for others)
  final Map<int, SubPhotoEntry> _articlePhotos = {};

  @override
  void dispose() {
    _signatureController.dispose();
    _pageController.dispose();
    _nosReferences.dispose();
    _clientFacture.dispose();
    _contactFacture.dispose();
    _addresseFacture.dispose();
    _telFacture.dispose();
    _emailFacture.dispose();
    _refFacture.dispose();
    _contactSinistre.dispose();
    _addresseSinistre.dispose();
    _telSinistre.dispose();
    _emailSinistre.dispose();
    _contexteIntervention.dispose();
    _infoAcces.dispose();
    _etatDemande.dispose();
    _textConclusion.dispose();
    _textPreconisations.dispose();
    _startTime.dispose();
    _endTime.dispose();
    _date.dispose();




     _techName.dispose();
    _localAdress.dispose();
    _localTel.dispose();
    _localMail.dispose();
    _doName.dispose();
    _objMission.dispose();
    _pageNumber.dispose();
    _dateTransmission.dispose();

    _standName.dispose();
    _standHall.dispose();
    _standNb.dispose();
    _salonName.dispose();
    _siteName.dispose();
    _siteAdress.dispose();
    _standDscrptn.dispose();
    _dateMontage.dispose();
    _dateEvnmt.dispose();
    _catErpType.dispose();
    _effectifMax.dispose();
    _orgaName.dispose();
    _installateurName.dispose();
    _exploitSiteName.dispose();
    _proprioMatosName.dispose();
    _nbStructures.dispose();
    _nbTableauxBesoin.dispose();
    _hauteur.dispose();
    _ouverture.dispose();
    _profondeur.dispose();
    _nbTower.dispose();
    _nbPalans.dispose();
    _marqueModelPP.dispose();
    _rideauxEnseignes.dispose();
    _poidGrilTotal.dispose();

    // Dispose per-gril controllers
    for (final c in _hauteurCtrls) c.dispose();
    for (final c in _ouvertureCtrls) c.dispose();
    for (final c in _profondeurCtrls) c.dispose();
    for (final c in _nbTowerCtrls) c.dispose();
    for (final c in _nbPalansCtrls) c.dispose();
    for (final c in _marqueModelPPCtrls) c.dispose();
    for (final c in _rideauxEnseignesCtrls) c.dispose();
    for (final c in _poidGrilTotalCtrls) c.dispose();

    _windSpeed.dispose();
    _docConsultName.dispose();
    _docConsultResp.dispose();

    _question1.dispose();
    _question2.dispose();
    _question3.dispose();
    _question4.dispose();
    _question5.dispose();
    _question6.dispose();
    _question7.dispose();
    _question8.dispose();
    _question9.dispose();
    _question10.dispose();
    _question11.dispose();
    _question12.dispose();
    _question13.dispose();


    _article3.dispose();
    _article5.dispose();
    _article6.dispose();
    _article7.dispose();
    _article9.dispose();
    _article10.dispose();
    _article11.dispose();
    _article5Obsrvt.dispose();
    _article6Obsrvt.dispose();
    _article7Obsrvt.dispose();
    _article9Obsrvt.dispose();
    _article10Obsrvt.dispose();
    _article11Obsrvt.dispose();
    _article12Obsrvt.dispose();
    _article13Obsrvt.dispose();
    _article14Obsrvt.dispose();
    _article15Obsrvt.dispose();
    _article16Obsrvt.dispose();
    _article17Obsrvt.dispose();
    _article18Obsrvt.dispose();
    _article19Obsrvt.dispose();
    _article20Obsrvt.dispose();
    _article21Obsrvt.dispose();
    _article22Obsrvt.dispose();
    _article23Obsrvt.dispose();
    _article24Obsrvt.dispose();
    _article25Obsrvt.dispose();
    _article26Obsrvt.dispose();
    _article27Obsrvt.dispose();
    _article28Obsrvt.dispose();
    _article29Obsrvt.dispose();
    _article30Obsrvt.dispose();
    _article31bsrvt.dispose();
    _article32bsrvt.dispose();
    _article33bsrvt.dispose();
    _article34bsrvt.dispose();
    _article36bsrvt.dispose();
    _article37bsrvt.dispose();
    _article38bsrvt.dispose();
    _article39bsrvt.dispose();
    _article45bsrvt.dispose();
    _article47bsrvt.dispose();
    _article48bsrvt.dispose();
    _article12.dispose();
    _article13.dispose();
    _article14.dispose();
    _article15.dispose();
    _article16.dispose();
    _article17.dispose();
    _article18.dispose();
    _article19.dispose();
    _article20.dispose();
    _article21.dispose();
    _article22.dispose();
    _article23.dispose();
    _article24.dispose();
    _article25.dispose();
    _article26.dispose();
    _article27.dispose();
    _article28.dispose();
    _article29.dispose();
    _article30.dispose();
    _article31.dispose();
    _article32.dispose();
    _article33.dispose();
    _article34.dispose();
    _article36.dispose();
    _article37.dispose();
    _article38.dispose();
    _article39.dispose();
    _article45.dispose();
    _article47.dispose();
    _article48.dispose();



    _avisFav.dispose();
    _avisDefav.dispose();

    _mailStand.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draftApplied) return;
    final __args = ModalRoute.of(context)?.settings.arguments;
    if (__args is Map && __args['draftId'] != null) {
      _draftId = __args['draftId'] as String?;
      final storage = StorageService();
      storage.loadDraft(_draftId!).then((json) {
        if (json != null && mounted) {
          setState(() {
            _loadFromDraftJson(json);
            _draftApplied = true;
          });
        }
      });
    } else {
      _draftApplied = true;
    }
  }

  Future<void> _saveDraft() async {
    final storage = StorageService();
    final id = await storage.saveDraft(_toDraftJson(), id: _draftId);
    if (mounted) {
      setState(() {
        _draftId = id;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fiche sauvegardée')),
      );
    }
  }

  void _goToNextPage() {
    if (_formKey1.currentState!.validate()) {
      _pageController.animateToPage(
        1,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage = 1);
    }
  }

  void _goToPreviousPage() {
    _pageController.animateToPage(
      0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = 0);
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _buildingPhotoPath = image.path;
      });
    }
  }
  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (!mounted) return;
      if (pickedFile != null) {
        setState(() {
          _buildingPhotoPath = pickedFile.path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'ouverture de la caméra: $e')),
      );
    }
  }

  // Take a photo for a specific article (example for 3,5,7)
  Future<void> _pickArticlePhoto(int articleIndex) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (!mounted) return;
      if (pickedFile != null) {
        setState(() {
          // Prefer the observation description for the article over the article number
          String obsText;
          switch (articleIndex) {
            case 3:
              obsText = _article3Obsrvt.text.trim();
              break;
            case 5:
              obsText = _article5Obsrvt.text.trim();
              break;
            case 7:
              obsText = _article7Obsrvt.text.trim();
              break;
            default:
              obsText = 'Article $articleIndex';
          }
          _articlePhotos[articleIndex] = SubPhotoEntry(
            number: '0', // will be replaced by its ObsNo during export
            description: obsText.isNotEmpty ? obsText : 'Article $articleIndex',
            imagePath: pickedFile.path,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la prise de photo (article $articleIndex): $e')),
      );
    }
  }

  // Pick a photo from the gallery for a specific article (e.g., Article 3)
  Future<void> _pickArticlePhotoFromGallery(int articleIndex) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (!mounted) return;
      if (pickedFile != null) {
        setState(() {
          // Prefer the observation description for the article over the article number
          String obsText;
          switch (articleIndex) {
            case 3:
              obsText = _article3Obsrvt.text.trim();
              break;
            case 5:
              obsText = _article5Obsrvt.text.trim();
              break;
            case 7:
              obsText = _article7Obsrvt.text.trim();
              break;
            default:
              obsText = 'Article $articleIndex';
          }
          _articlePhotos[articleIndex] = SubPhotoEntry(
            number: '0', // will be replaced by its ObsNo during export
            description: obsText.isNotEmpty ? obsText : 'Article $articleIndex',
            imagePath: pickedFile.path,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection depuis la galerie (article $articleIndex): $e')),
      );
    }
  }

  Future<void> _saveSignature() async {
    try {
      final bytes = await _signatureController.toPngBytes();
      if (bytes == null || bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez signer dans la zone prévue.')),
        );
        return;
      }
      if (kIsWeb) {
        // On web, keep the signature in memory and avoid filesystem
        if (!mounted) return;
        setState(() {
          _signatureBytes = Uint8List.fromList(bytes);
          _signaturePath = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signature enregistrée (web).')),
        );
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      setState(() {
        _signaturePath = file.path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signature enregistrée.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'enregistrement de la signature: $e')),
      );
    }
  }

  Future<void> _createSubPhoto() async {
    final result = await showDialog<SubPhotoEntry>(
      context: context,
      builder: (context) => const SubPhotoDialog(),
    );

    if (result != null) {
      setState(() {
        _subPhotos.add(result);
      });
    }
  }

  Future<void> _generateWordFile({bool preview = false}) async {
    if (!_formKey2.currentState!.validate()) return;

    try {
      print('🔄 Loading template...');
      final ByteData data = await rootBundle.load('assets/template_ve.docx');
      print('✅ Template loaded, length: ${data.lengthInBytes}');

      final Uint8List bytes = data.buffer.asUint8List();
      final docx = await DocxTemplate.fromBytes(bytes);

      final tags = docx.getTags();
      print('🏷️ Found tags in template: $tags');
      print('🏷️ Template tags found: $tags');
      print('   Contains PhotosTable? ${tags.contains("PhotosTable")}');

      final content = Content();

      // Page 1 fields
      content.add(TextContent('NosReferences', _nosReferences.text.trim()));
      content.add(TextContent('ClientFacture', _clientFacture.text.trim().toUpperCase()));
      content.add(TextContent('ContactFacture', _contactFacture.text.trim()));
      content.add(TextContent('AddresseFacture', _addresseFacture.text.trim()));
      content.add(TextContent('TelFacture', _telFacture.text.trim()));
      content.add(TextContent('EmailFacture', _emailFacture.text.trim()));
      content.add(TextContent('RefFacture', _refFacture.text.trim()));
      content.add(TextContent('ContactSinistre', _contactSinistre.text.trim()));
      content.add(TextContent('AddresseSinistre', _addresseSinistre.text.trim()));
      content.add(TextContent('TelSinistre', _telSinistre.text.trim()));
      content.add(TextContent('EmailSinistre', _emailSinistre.text.trim()));
      content.add(TextContent('ContexteIntervention', _contexteIntervention.text.trim()));
      content.add(TextContent('InfoAcces', _infoAcces.text.trim()));
      content.add(TextContent('EtatDemande', _etatDemande.text.trim()));
      content.add(TextContent('startTime', _startTime.text.trim()));
      content.add(TextContent('EndTime', _endTime.text.trim()));
      content.add(TextContent('Date', _date.text.trim()));


      content.add(TextContent('TechName', _techName.text.trim()));
      content.add(TextContent('LocalAdress', _localAdress.text.trim()));
      content.add(TextContent('LocalTel', _localTel.text.trim()));
      content.add(TextContent('LocalMail', _localMail.text.trim()));
      content.add(TextContent('DoName', _doName.text.trim()));
      content.add(TextContent('ObjMission', _objMission.text.trim()));
      content.add(TextContent('PageNumber', _pageNumber.text.trim()));
      content.add(TextContent('DateTransmission', _dateTransmission.text.trim()));

      content.add(TextContent('StandName', _standName.text.trim()));
      content.add(TextContent('StandHall', _standHall.text.trim()));
      content.add(TextContent('StandNb', _standNb.text.trim()));
      content.add(TextContent('SalonName', _salonName.text.trim()));
      content.add(TextContent('SiteName', _siteName.text.trim()));
      content.add(TextContent('SiteAdress', _siteAdress.text.trim()));
      content.add(TextContent('StandDescription', _standDscrptn.text.trim()));
      content.add(TextContent('DateMontage', _dateMontage.text.trim()));
      content.add(TextContent('DateEvenement', _dateEvnmt.text.trim()));
      content.add(TextContent('CatErpType', _catErpType.text.trim()));
      content.add(TextContent('EffectifMax', _effectifMax.text.trim()));
      content.add(TextContent('OrgaName', _orgaName.text.trim()));
      content.add(TextContent('InstallateurName', _installateurName.text.trim()));
      content.add(TextContent('ExploitSiteName', _exploitSiteName.text.trim()));
      content.add(TextContent('ProprioMatosName', _proprioMatosName.text.trim()));
      content.add(TextContent('NbStructures', _nbStructures.text.trim()));
      content.add(TextContent('NbTableauxBesoin', _nbTableauxBesoin.text.trim()));
      content.add(TextContent('Hauteur', _grilValueForExport(_hauteurCtrls, _hauteur)));
      content.add(TextContent('Ouverture', _grilValueForExport(_ouvertureCtrls, _ouverture)));
      content.add(TextContent('Profondeur', _grilValueForExport(_profondeurCtrls, _profondeur)));
      content.add(TextContent('NbTower', _grilValueForExport(_nbTowerCtrls, _nbTower)));
      content.add(TextContent('NbPalans', _grilValueForExport(_nbPalansCtrls, _nbPalans)));
      content.add(TextContent('MarqueModelPP', _grilValueForExport(_marqueModelPPCtrls, _marqueModelPP)));
      content.add(TextContent('RideauxEnseignes', _grilValueForExport(_rideauxEnseignesCtrls, _rideauxEnseignes)));
      content.add(TextContent('PoidGrilTotal', _grilValueForExport(_poidGrilTotalCtrls, _poidGrilTotal)));
      content.add(TextContent('WindSpeed', _windSpeed.text.trim()));
      content.add(TextContent('DocConsultName', _docConsultName.text.trim()));
      content.add(TextContent('DocConsultResp', _docConsultResp.text.trim()));


      for (int i = 1; i <= 13; i++) {
        bool? value = checkboxValues[i];
        print('  Question $i: ${checkboxValues[i]}');

        // Marquer un "x" dans les colonnes Oui/Non du document généré
        content.add(TextContent('Question${i}Oui', value == true ? 'x' : ' '));
        content.add(TextContent('Question${i}Non', value == false ? 'x' : ' '));

        // Commentaire associé à la ligne i
        String comment = '';
        switch (i) {
          case 1: comment = _question1.text.trim(); break;
          case 2: comment = _question2.text.trim(); break;
          case 3: comment = _question3.text.trim(); break;
          case 4: comment = _question4.text.trim(); break;
          case 5: comment = _question5.text.trim(); break;
          case 6: comment = _question6.text.trim(); break;
          case 7: comment = _question7.text.trim(); break;
          case 8: comment = _question8.text.trim(); break;
          case 9: comment = _question9.text.trim(); break;
          case 10: comment = _question10.text.trim(); break;
          case 11: comment = _question11.text.trim(); break;
          case 12: comment = _question12.text.trim(); break;
          case 13: comment = _question13.text.trim(); break;
        }
        content.add(TextContent('Question${i}Comment', comment));
      }

      for (int i = 1; i <= 48; i++) {
        // Use the S/NS/SO/HM selection map (String?) for article rows
        String? value = checkboxValues2[i];

        // Put an "x" in the matching column in the generated document
        content.add(TextContent('Article${i}S', value == 'S' ? 'x' : ' '));
        content.add(TextContent('Article${i}NS', value == 'NS' ? 'x' : ' '));
        content.add(TextContent('Article${i}SO', value == 'SO' ? 'x' : ' '));
        content.add(TextContent('Article${i}HM', value == 'HM' ? 'x' : ' '));


        // If you later want to export per-article comments, fill comment here
        String comment = '';
        switch (i) {
          case 1: comment = _article3.text.trim(); break;
          case 2: comment = _article5.text.trim(); break;
          case 3: comment = _article6.text.trim(); break;
          case 4: comment = _article7.text.trim(); break;
          case 5: comment = _article9.text.trim(); break;
          case 6: comment = _article10.text.trim(); break;
          case 7: comment = _article11.text.trim(); break;
        }
        content.add(TextContent('Article${i}Comment', comment));

      }

      content.add(TextContent('Article3Observations', _article3Obsrvt.text.trim()));
      content.add(TextContent('Article5Observations', _article5Obsrvt.text.trim()));
      content.add(TextContent('Article6Observations', _article6Obsrvt.text.trim()));
      content.add(TextContent('Article7Observations', _article7Obsrvt.text.trim()));
      content.add(TextContent('Article9Observations', _article9Obsrvt.text.trim()));
      content.add(TextContent('Article10Observations', _article10Obsrvt.text.trim()));
      content.add(TextContent('Article11Observations', _article11Obsrvt.text.trim()));

      content.add(TextContent('Article12Observations', _article12Obsrvt.text.trim()));
      content.add(TextContent('Article13Observations', _article13Obsrvt.text.trim()));
      content.add(TextContent('Article14Observations', _article14Obsrvt.text.trim()));
      content.add(TextContent('Article15Observations', _article15Obsrvt.text.trim()));
      content.add(TextContent('Article16Observations', _article16Obsrvt.text.trim()));
      content.add(TextContent('Article17Observations', _article17Obsrvt.text.trim()));
      content.add(TextContent('Article18Observations', _article18Obsrvt.text.trim()));
      content.add(TextContent('Article19Observations', _article19Obsrvt.text.trim()));
      content.add(TextContent('Article20Observations', _article20Obsrvt.text.trim()));
      content.add(TextContent('Article21Observations', _article21Obsrvt.text.trim()));
      content.add(TextContent('Article22Observations', _article22Obsrvt.text.trim()));
      content.add(TextContent('Article23Observations', _article23Obsrvt.text.trim()));
      content.add(TextContent('Article24Observations', _article24Obsrvt.text.trim()));
      content.add(TextContent('Article25Observations', _article25Obsrvt.text.trim()));
      content.add(TextContent('Article26Observations', _article26Obsrvt.text.trim()));
      content.add(TextContent('Article27Observations', _article27Obsrvt.text.trim()));
      content.add(TextContent('Article28Observations', _article28Obsrvt.text.trim()));
      content.add(TextContent('Article29Observations', _article29Obsrvt.text.trim()));
      content.add(TextContent('Article30Observations', _article30Obsrvt.text.trim()));
      content.add(TextContent('Article31Observations', _article31bsrvt.text.trim()));
      content.add(TextContent('Article32Observations', _article32bsrvt.text.trim()));
      content.add(TextContent('Article33Observations', _article33bsrvt.text.trim()));
      content.add(TextContent('Article34Observations', _article34bsrvt.text.trim()));
      content.add(TextContent('Article36Observations', _article36bsrvt.text.trim()));
      content.add(TextContent('Article37Observations', _article37bsrvt.text.trim()));
      content.add(TextContent('Article38Observations', _article38bsrvt.text.trim()));
      content.add(TextContent('Article39Observations', _article39bsrvt.text.trim()));
      content.add(TextContent('Article45Observations', _article45bsrvt.text.trim()));
      content.add(TextContent('Article47Observations', _article47bsrvt.text.trim()));
      content.add(TextContent('Article48Observations', _article48bsrvt.text.trim()));


      // Building photo
      if (_buildingPhotoPath.isNotEmpty ) {
        final photoBytes = await File(_buildingPhotoPath).readAsBytes();
        content.add(ImageContent('PhotoGenerale', photoBytes));
      }

      // Build Rappel des observations from NS items in the verification table
      final obsRows = <RowContent>[];
      int obsIndex = 1;
      // Map each article index to its generated observation number (ObsNo)
      final Map<int, int> articleToObsNo = {};
      for (int i = 1; i <= 48; i++) {
        if (checkboxValues2[i] == 'NS') {
          String obsComment = '';
          switch (i) {
            case 3:
              obsComment = _article3Obsrvt.text.trim();
              break;
            case 5:
              obsComment = _article5Obsrvt.text.trim();
              break;
            case 6:
              obsComment = _article6Obsrvt.text.trim();
              break;
            case 7:
              obsComment = _article7Obsrvt.text.trim();
              break;
            case 9:
              obsComment = _article9Obsrvt.text.trim();
              break;
            case 10:
              obsComment = _article10Obsrvt.text.trim();
              break;
            case 11:
              obsComment = _article11Obsrvt.text.trim();
              break;
            case 12:
              obsComment = _article12Obsrvt.text.trim();
              break;
            case 13:
              obsComment = _article13Obsrvt.text.trim();
              break;
            case 14:
              obsComment = _article14Obsrvt.text.trim();
              break;
            case 15:
              obsComment = _article15Obsrvt.text.trim();
              break;
            case 16:
              obsComment = _article16Obsrvt.text.trim();
              break;
            case 17:
              obsComment = _article17Obsrvt.text.trim();
              break;
            case 18:
              obsComment = _article18Obsrvt.text.trim();
              break;
            case 19:
              obsComment = _article19Obsrvt.text.trim();
              break;
            case 20:
              obsComment = _article20Obsrvt.text.trim();
              break;
            case 21:
              obsComment = _article21Obsrvt.text.trim();
              break;
            case 22:
              obsComment = _article22Obsrvt.text.trim();
              break;
            case 23:
              obsComment = _article23Obsrvt.text.trim();
              break;
            case 24:
              obsComment = _article24Obsrvt.text.trim();
              break;
            case 25:
              obsComment = _article25Obsrvt.text.trim();
              break;
            case 26:
              obsComment = _article26Obsrvt.text.trim();
              break;
            case 27:
              obsComment = _article27Obsrvt.text.trim();
              break;
            case 28:
              obsComment = _article28Obsrvt.text.trim();
              break;
            case 29:
              obsComment = _article29Obsrvt.text.trim();
              break;
            case 30:
              obsComment = _article3Obsrvt.text.trim();
              break;
            case 31:
              obsComment = _article31bsrvt.text.trim();
              break;
            case 32:
              obsComment = _article32bsrvt.text.trim();
              break;
            case 33:
              obsComment = _article33bsrvt.text.trim();
              break;
            case 34:
              obsComment = _article34bsrvt.text.trim();
              break;
            case 36:
              obsComment = _article36bsrvt.text.trim();
              break;
            case 37:
              obsComment = _article37bsrvt.text.trim();
              break;
            case 38:
              obsComment = _article38bsrvt.text.trim();
              break;
            case 39:
              obsComment = _article39bsrvt.text.trim();
              break;
            case 45:
              obsComment = _article45bsrvt.text.trim();
              break;
            case 47:
              obsComment = _article47bsrvt.text.trim();
              break;
            case 48:
              obsComment = _article48bsrvt.text.trim();
              break;

            default:
              obsComment = '';
          }

          final row = RowContent()
            ..add(TextContent('ObsNo', obsIndex.toString()))
            ..add(TextContent('ObsDetail', obsComment))
            ..add(TextContent('ObsArticleRef', i.toString()))
           // ..add(TextContent('ObsPhotoNo', ''));
            ..add(TextContent('ObsPhotoNo', obsIndex.toString()));

          // Remember which photo number corresponds to which article
          articleToObsNo[i] = obsIndex;

          obsRows.add(row);
          obsIndex++;
        }
      }
      if (obsRows.isNotEmpty) {
        content.add(TableContent('ObservationsTable', obsRows));
      }

      // Build the Photos table by merging general sub-photos and per-article NS photos
      final photoRows = <RowContent>[];

      // 1) Existing additional photos entered by the user
      for (var photo in _subPhotos) {
        print('  Processing extra photo: ${photo.imagePath}');
        final imageBytes = await File(photo.imagePath).readAsBytes();
        final row = RowContent()
          ..add(ImageContent('PhotoImage', imageBytes))
          ..add(TextContent('PhotoDescription', 'Photo n° ${photo.number}: ${photo.description}'));
        photoRows.add(row);
      }

      // 2) Per-article photos (example for 3, 5, 7). Use the mapped ObsNo so it matches ObsPhotoNo in ObservationsTable
      for (final i in [3, 5, 7]) {
        final entry = _articlePhotos[i];
        final obsNo = articleToObsNo[i];
        if (entry != null && obsNo != null) {
          print('  Processing article $i photo for ObsNo $obsNo: ${entry.imagePath}');
          final imageBytes = await File(entry.imagePath).readAsBytes();
          final obsTextForPhoto = (() {
            switch (i) {
              case 3:
                return _article3Obsrvt.text.trim();
              case 5:
                return _article5Obsrvt.text.trim();
              case 7:
                return _article7Obsrvt.text.trim();
              default:
                return 'Article $i';
            }
          })();
          final row = RowContent()
            ..add(ImageContent('PhotoImage', imageBytes))
            ..add(TextContent('PhotoDescription', 'Photo n° $obsNo: $obsTextForPhoto'));
          photoRows.add(row);
        }
      }


      for (int i = 1; i <= 2; i++) {
        bool? value = checkboxValues[i];

        // Marquer un "x" dans les colonnes Oui/Non du document généré
        content.add(TextContent('Avis${i}Favorable', value == true ? 'x' : ' '));
        content.add(TextContent('Avis${i}Defavorable', value == false ? 'x' : ' '));

       }


      // 3) Signature appended as a photo row and as a dedicated tag if present
      if (_signatureBytes != null && _signatureBytes!.isNotEmpty) {
        try {
          final sigBytes = _signatureBytes!;
          content.add(ImageContent('SignatureImage', sigBytes));
        } catch (e) {
          print('⚠️ Unable to add signature image (web/memory): $e');
        }
      } else if (_signaturePath.isNotEmpty) {
        try {
          final sigBytes = await File(_signaturePath).readAsBytes();
          content.add(ImageContent('SignatureImage', sigBytes));
        } catch (e) {
          print('⚠️ Unable to add signature image (file): $e');
        }
      }


      if (photoRows.isNotEmpty) {
        content.add(TableContent('AnomaliesTable', photoRows));
        print('✅ Added TableContent with ${photoRows.length} rows');
        print('   Content now has keys: ${content.keys.toList()}');
      } else {
        print('⚠️ No photos to add');
      }

      // Generate document
      print('✏️ Generating document...');
      final generated = await docx.generate(
        content,
        tagPolicy: TagPolicy.removeAll,
      );

      if (generated == null) {
        print('❌ Failed to generate document');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Document generation failed')),
        );
        return;
      }

      print('✅ Generated document size: ${generated.length} bytes');

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/filled_$timestamp.docx');
      await file.writeAsBytes(generated);
      
      print('💾 File saved at: ${file.path}');
      
      if (mounted) {
        setState(() {
          _lastGeneratedDocPath = file.path;
        });
      }
      
      if (!mounted) return;

      if (preview) {
        // Try to open the generated document for a quick preview
        await OpenFilex.open(file.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('👁️ Aperçu ouvert: ${file.path}'),
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Saved: ${file.path}'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stacktrace) {
      print('❌ Error: $e');
      print('📋 Stacktrace: $stacktrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }
     Future<String> _generatePdfFromData() async {
      try {
        // Colors (approximate to app brand)
        final PdfColor rose = PdfColor.fromInt(0xFF008D); // #FF008D
        final PdfColor grisClair = PdfColors.grey300;
        final PdfColor grisTexte = PdfColors.grey700;
        final logoBytes = await rootBundle.load('assets/logo.png');
        final logoBytes2 = await rootBundle.load('assets/footer.png');
        final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
        final footerImage = pw.MemoryImage(logoBytes2.buffer.asUint8List());

        final pdf = pw.Document();
        final dateStr = DateFormat('dd_MM_yyyy_HH_mm').format(DateTime.now());
        final ref = _nosReferences.text.trim();

        pw.Widget buildHeader(pw.Context context) {
          return pw.Container(
            child: pw.Row(

                  children: [
                pw.Image(
                logoImage,
                  width: 550,
                  height: 200,
                fit: pw.BoxFit.contain,

                )
                  ],
            ),
          );
        }

        pw.Widget buildFooter(pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Column(
              children: [
                pw.SizedBox(height: 4),
                pw.Image(
                    footerImage,

                    width: 550,
                    height: 165,
                    fit: pw.BoxFit.contain,

                  ),
                pw.SizedBox(height: 2),
                pw.Text('Page ${context.pageNumber} sur ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7)),
              ],
            ),
          );
        }

        pw.Widget keyValueRow(String key, String value) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.5),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 140, child: pw.Text(key, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
              ],
            ),
          );
        }


        pw.TableRow keyValueTableRow(String key, String value) {
          return pw.TableRow(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  border: pw.Border(
                    right: pw.BorderSide(color: PdfColors.grey700, width: 1.2), // separating bar
                  ),
                ),
                child: pw.Text(
                  key,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  value,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        }


        pw.Widget infoTablePage(pw.Context pdfContext, {int? totalPagesOverride}) {
          return pw.Column(children: [
            pw.SizedBox(height: 10),
            pw.SizedBox(height: 30),  // Plus d'espace

            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: 2), color: PdfColors.grey300),
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              alignment: pw.Alignment.center,
              child: pw.Text('RAPPORT DE VÉRIFICATION APRÈS MONTAGE',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.SizedBox(height: 20),

            pw.Text('Un rapport pour tous les ensembles démontables identiques', style: pw.TextStyle(fontSize: 9, color: grisTexte)),
            pw.SizedBox(height: 10),
            pw.Text("Conformément à l'article 38 de l'arrêté du 25 juillet 2022 modifié", style: pw.TextStyle(fontSize: 8, color: grisTexte, fontStyle: pw.FontStyle.italic)),
            pw.SizedBox(height: 12),
            pw.SizedBox(height: 20),
            pw.SizedBox(height: 10),  // Plus d'espace


            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: 2)),
              child: pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(100),
                  1: const pw.FixedColumnWidth(200),
                },
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 2),
                ),
                 children: [
                  keyValueTableRow('Technicien compétent', _techName.text.trim()),
                  keyValueTableRow('Adresse', _localAdress.text.trim()),
                  keyValueTableRow('Téléphone', _localTel.text.trim()),
                  keyValueTableRow('Mail', _localMail.text.trim()),
                  keyValueTableRow("Donneur d'ordres", _doName.text.trim()),
                  keyValueTableRow('Objet de la mission', _objMission.text.trim()),
                  keyValueTableRow('Nombre de pages',   (totalPagesOverride != null && totalPagesOverride > 0)
                      ? totalPagesOverride.toString()
                      : (pdfContext.pagesCount > 0 ? pdfContext.pagesCount.toString() : '-')), 
                  keyValueTableRow('Date de transmission', _dateTransmission.text.trim()),
                ],
              ),
            ),
          ]);
        }

        pw.Widget preambulePage() {
          return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Center(child: pw.Text('PRÉAMBULE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 20),
            pw.Text(
              "Les dispositions légales du code de la construction et de l'habitation imposent aux structures provisoires et démontables qu'elles soient conçues et dimensionnées "
                  "de sorte qu'elles résistent durablement à l\'effet combiné de leur propre poids, des charges climatiques extrêmes et des surcharges d'exploitation correspondant à leur usage normal (article L. 131-1). "
                  "L\'arrêté du 25 juillet 2022 modifié permet prioritairement de répondre à cet objectif général de solidité et de stabilité des "
                  "structures. D'autres sujets connexes complètent l'arrêté et contribuent á la sécurité des personnes sans impacter la solidité et "
                  "la stabilité des structures. "
                  "\n\nL\'avis final de l\'organisme accrédité ou du technicien compétent porte sur toutes les dispositions de l\'arrêté listées dans "
                  "le tableau de vérification qui doit être joint au rapport. Toutefois, certaines dispositions à l\'exception de celles portant sur la solidité et la stabilité de "
                  "la structure peuvent être notées « hors missions » (HM) en accord avec l\'organisateur. Dans ce cas, l\'avis final sera complété par une observation à destination "
                  "de l\'organisateur permettant de préciser le périmètre de l\'avis favorable. \n"
                  "\n\nNos observations décrivent les écarts constatés par rapport aux référentiels indiqués dans le tableau des vérifications. Des recommandations sur les suites à "
                  "donner peuvent y être associées, cependant, le choix de la solution définitive vous appartient."
                  "\n\nD\'autre part, l\'absence d\'observation signifie que, lors de notre passage, l\'installation ou l\'équipement ne présentait pas d\'anomalie en rapport avec l\'objet de la mission. "
                  "Bien entendu, si une vérification n\'a pas pu être effectuée, cette information est mentionnée et justifiée."
                  "\n\nD\'une façon générale, les observations et résultats figurant dans ce rapport sont exprimés selon les informations recueillies, les conditions de vérification et les constats "
                  "réalisés à la date de notre intervention. Notre inspection est figée par un reportage photographique horodaté.",

              style: const pw.TextStyle(fontSize: 9),
              textAlign: pw.TextAlign.justify,
            ),
            pw.SizedBox(height: 50),
            pw.Center(child: pw.Text('CONTENU DE LA MISSION', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 30),

             pw.Text('Notre mission consiste à procéder à l\'inspection sur site de(s) ensemble(s) démontable(s) installé(s) dans le cadre de l\'évènement : ', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 10),
            pw.Text('Qui se déroulera le : ${_dateEvnmt.text}', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 10),
            pw.Text('Sur le site: ${_siteName.text}, Hall ${_standHall.text}, Stand ${_standNb.text}', style: const pw.TextStyle(fontSize: 10)),

          ]);
        }

        pw.Widget referentielPage() {
          List<String> regles = [
            "Articles L.131-1 et L.134-12 du code de la construction et de l\'habitation qui fixent des objectifs généraux de solidité, de stabilité et de protection contre les chutes de hauteur des structures provisoires et démontables.",
            "Arrêté du 25 juillet 2022 fixant les règles de sécurité et les dispositions techniques applicables aux structures provisoires et démontables.",
            "Arrêté du 30 octobre 2023 modifiant l\'arrêté du 25 juin 1980 portant approbation des dispositions générales du règlement de sécurité contre les risques d\'incendie et de panique dans les établissements recevant du public.",
            "Arrêté du 4 décembre 2023 modifiant l\'arrêté du 25 juillet 2022 fixant les règles de sécurité et les dispositions techniques applicables aux structures provisoires et démontables",
            "Arrêté du 25 juin 1980 modifié \-règlement de sécurité contre les risques d\'incendie et de panique dans les ERP",
            "Arrêter du 1er mars 2004 relatif aux vérifications des appareils et accessoires de levage.",
          ];
          List<String> normatifV = [
            "Norme NF P 01-012 relative aux dimensions des garde-corps et rampes d'escalier",
            "Normes NF EN 12810-1, -2 et 12811-1, -2 et -3, échafaudages de type \"multi directionnels\" ",
             ];
          List<String> normatifF = [
            "Norme NF P 06-001 relative aux surcharges d'exploitation ou NF EN 1991-1-1",
            "Règles normatives applicables (CM66, CB 71, NV 65 révisé ou Eurocodes avec leurs documents d'application nationaux)",
          ];
          List<String> normatifV2 = [
            "Norme NF-P 90.500 et NF EN 13200-6 pour les tribunes démontables",
          ];
          List<String> normatifF2 = [
            "NF EN 17795-5 Opérations de levage et de mouvement dans l\'industrie de l\'événementiel",
            "NF EN 17115 Conception et fabrication de poutres en aluminium et acier",
            "NF EN 14492-2 Appareils de levage à charge suspendue - treuils et palans motorisés",

          ];
          List<String> normatifV3 = [
             "NF EN 17206 Machinerie pour scène et autres zones de production"
          ];
          List<String> normatifF3 = [
            "Les notices techniques des fabricants de matériels",
            "Memento de l\'élingueur (INRS)",
          ];
          List<String> normatifV4 = [
            "Recommandation R408",
            "Guide professionnel des tribunes à structures métalliques édité par Union Sport et Cycle",
          ];
          List<String> normatifF4 = [
            "Guide de Travail - Grues et appareils de levage de Michel Munoz",
            "Guide pratique du ministère de l\'intérieur",
          ];
          return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Center(child: pw.Text('RÉFÉRENTIELS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 30),
            pw.Text('RÉGLEMENTAIRES', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 14),
            ...regles.map((e) => pw.Row(children: [
              pw.Container(width: 8, height: 8, color: PdfColors.black), pw.SizedBox(width: 6), pw.Expanded(child: pw.Text(e, style: const pw.TextStyle(fontSize: 9)))
            ])),
            pw.SizedBox(height: 14),
            pw.Text('NORMATIFS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 14),

            ...normatifV.map((e) => pw.Row(children: [
              pw.Container(width: 8, height: 8, decoration: pw.BoxDecoration(
                color: PdfColors.white,  // Remplissage blanc
                border: pw.Border.all(
                  color: PdfColors.black,  // Contour noir
                  width: 1,
                ),
              ),), pw.SizedBox(width: 6), pw.Expanded(child: pw.Text(e, style: const pw.TextStyle(fontSize: 9)))
            ])),
            ...normatifF.map((e) => pw.Row(children: [
              pw.Container(width: 8, height: 8, color: PdfColors.black), pw.SizedBox(width: 6), pw.Expanded(child: pw.Text(e, style: const pw.TextStyle(fontSize: 9)))
            ])),
            ...normatifV2.map((e) => pw.Row(children: [
              pw.Container(width: 8, height: 8, decoration: pw.BoxDecoration(
                color: PdfColors.white,  // Remplissage blanc
                border: pw.Border.all(
                  color: PdfColors.black,  // Contour noir
                  width: 1,
                ),
              ),), pw.SizedBox(width: 6), pw.Expanded(child: pw.Text(e, style: const pw.TextStyle(fontSize: 9)))
            ])),
            ...normatifF2.map((e) => pw.Row(children: [
              pw.Container(width: 8, height: 8, color: PdfColors.black), pw.SizedBox(width: 6), pw.Expanded(child: pw.Text(e, style: const pw.TextStyle(fontSize: 9)))
            ])),
            ...normatifV3.map((e) => pw.Row(children: [
              pw.Container(width: 8, height: 8, decoration: pw.BoxDecoration(
                color: PdfColors.white,  // Remplissage blanc
                border: pw.Border.all(
                  color: PdfColors.black,  // Contour noir
                  width: 1,
                ),
              ),), pw.SizedBox(width: 6), pw.Expanded(child: pw.Text(e, style: const pw.TextStyle(fontSize: 9)))
            ])),
            pw.SizedBox(height: 4),
            pw.SizedBox(height: 10),

            pw.Text('TECHNIQUES', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 14),

             ...normatifF3.map((e) => pw.Row(children: [
              pw.Container(width: 8, height: 8, color: PdfColors.black), pw.SizedBox(width: 6), pw.Expanded(child: pw.Text(e, style: const pw.TextStyle(fontSize: 9)))
            ])),
            ...normatifV4.map((e) => pw.Row(children: [
              pw.Container(width: 8, height: 8, decoration: pw.BoxDecoration(
                color: PdfColors.white,  // Remplissage blanc
                border: pw.Border.all(
                  color: PdfColors.black,  // Contour noir
                  width: 1,
                ),
              ),), pw.SizedBox(width: 6), pw.Expanded(child: pw.Text(e, style: const pw.TextStyle(fontSize: 9)))
            ])),
            ...normatifF4.map((e) => pw.Row(children: [
              pw.Container(width: 8, height: 8, color: PdfColors.black), pw.SizedBox(width: 6), pw.Expanded(child: pw.Text(e, style: const pw.TextStyle(fontSize: 9)))
            ])),
          ]);
        }


        pw.Widget renseignements() {
          return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Center(child: pw.Text('RENSEIGNEMENTS CONCERNANT L\'ÉVÈNEMENT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 10),

            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: 2)),
              child: pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(100),
                  1: const pw.FixedColumnWidth(200),
                },
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 2),
                ),
                children: [
                  keyValueTableRow('Nom', _salonName.text.trim()),
                  keyValueTableRow('Site', _siteName.text.trim()),
                  keyValueTableRow('Stand', _standHall.text.trim() ),//_standNb.text.trim()
                  keyValueTableRow('Adresse', _siteAdress.text.trim()),
                  keyValueTableRow("Description Sommaire", _standDscrptn.text.trim()),
                  keyValueTableRow('Date du montage', _dateMontage.text.trim()),
                  keyValueTableRow('Date évènement', _dateEvnmt.text.trim()),
                  keyValueTableRow('Catégorie et type ERP', _catErpType.text.trim()),
                  keyValueTableRow('Effectif max du public admissible', _effectifMax.text.trim()),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            pw.Center(child: pw.Text('RENSEIGNEMENTS CONCERNANT LES INTERVENANTS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 10),

          pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: 2)),
          child: pw.Table(
          columnWidths: {
          0: const pw.FixedColumnWidth(100),
          1: const pw.FixedColumnWidth(200),
          },
          border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 2),
          ),
          children: [
          keyValueTableRow('Organisateur', _orgaName.text.trim()),
          keyValueTableRow('Installateur', _installateurName.text.trim()),
          keyValueTableRow('Exploitant du site', _exploitSiteName.text.trim()),
          keyValueTableRow('Propriétaire', _proprioMatosName.text.trim()),
          ],
          ),
          ),
            pw.SizedBox(height: 10),

            pw.Center(child: pw.Text('RENSEIGNEMENTS CONCERNANT L\'ENSEMBLE DÉMONTABLE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 20),

            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: 2)),
              child: pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(100),
                  1: const pw.FixedColumnWidth(200),
                },
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 2),
                ),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey500,  // Fond gris pour différencier
                    ),
                    children: [
                      pw.Container(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Scène et plateforme',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        // Cette cellule couvre les 2 colonnes
                      ),
                      pw.SizedBox(),  // Cellule vide (requise par TableRow mais sera ignorée visuellement)
                    ],
                  ),

                  keyValueTableRow('Ouverture', '-------------------------------'),
                  keyValueTableRow('Profondeur', '-------------------------------'),
                  keyValueTableRow('Hauteur calage compris', '-------------------------------'),
                  keyValueTableRow('Habillage', '-------------------------------'),
                  keyValueTableRow("Marque et modèle", '-------------------------------'),
                  keyValueTableRow('Garde-corps','-------------------------------'),
                ],
              ),
            ),
          ]);
        }

        pw.Widget renseignements2() {
          // Build one separate table per gril to avoid mixing values across grils
          pw.Widget buildGrilTable(int i) {
            String getVal(List<TextEditingController> list, TextEditingController single) {
              if (list.isNotEmpty && i < list.length) return list[i].text.trim();
              return single.text.trim();
            }

            return pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: 2)),
              child: pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(100),
                  1: const pw.FixedColumnWidth(200),
                },
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 2),
                ),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey500),
                    children: [
                      pw.Container(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Gril technique - Gril ${i + 1}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.SizedBox(),
                    ],
                  ),
                  keyValueTableRow('Hauteur', getVal(_hauteurCtrls, _hauteur)),
                  keyValueTableRow('Ouverture', getVal(_ouvertureCtrls, _ouverture)),
                  keyValueTableRow('Profondeur', getVal(_profondeurCtrls, _profondeur)),
                  keyValueTableRow('Si élevé sur pieds, Nombre de Towers', getVal(_nbTowerCtrls, _nbTower)),
                  keyValueTableRow('Si suspendu, Nombre de palans', getVal(_nbPalansCtrls, _nbPalans)),
                  keyValueTableRow('Marque et modèle poutres et palans', getVal(_marqueModelPPCtrls, _marqueModelPP)),
                  keyValueTableRow('Rideaux', getVal(_rideauxEnseignesCtrls, _rideauxEnseignes)),
                  keyValueTableRow('Poids total du gril équipé', getVal(_poidGrilTotalCtrls, _poidGrilTotal)),
                ],
              ),
            );
          }

          final grilCount = _hauteurCtrls.isNotEmpty ? _hauteurCtrls.length : 1;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Render each gril as its own table; MultiPage will handle page overflow between widgets
              ...List.generate(grilCount, (i) => pw.Column(children: [
                    buildGrilTable(i),
                    pw.SizedBox(height: 12),
                  ])),

              pw.SizedBox(height: 20),

              pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: 2)),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FixedColumnWidth(100),
                    1: const pw.FixedColumnWidth(200),
                  },
                  border: pw.TableBorder(
                    horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 2),
                  ),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey500,  // Fond gris pour différencier
                      ),
                      children: [
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Échafaudages, tour, passerelles',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,

                          ),
                          // Cette cellule couvre les 2 colonnes
                        ),
                        pw.SizedBox(),  // Cellule vide (requise par TableRow mais sera ignorée visuellement)
                      ],
                    ),

                    keyValueTableRow('Hauteur', '-------------------------------'),
                    keyValueTableRow('Largeur', '-------------------------------'),
                    keyValueTableRow('Longueur', '-------------------------------'),
                    keyValueTableRow('Bardage', '-------------------------------'),
                    keyValueTableRow("Si lestage, poids", '-------------------------------'),
                    keyValueTableRow('Haubanage','-------------------------------'),
                    keyValueTableRow('Poids total de la structure','-------------------------------'),
                    keyValueTableRow('Marque et modèle','-------------------------------'),
                    keyValueTableRow('Si tour, usage ','-------------------------------'),
                  ],
                ),
              ),

            ],
          );
        }

        pw.Widget renseignements3() {
          return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [

            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: 2)),
              child: pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(100),
                  1: const pw.FixedColumnWidth(200),
                },
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 2),
                ),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey500,  // Fond gris pour différencier
                    ),
                    children: [
                      pw.Container(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Tribunes',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,

                        ),
                        // Cette cellule couvre les 2 colonnes
                      ),
                      pw.SizedBox(),  // Cellule vide (requise par TableRow mais sera ignorée visuellement)
                    ],
                  ),

                  keyValueTableRow('Hauteur dernier rang', '-------------------------------'),
                  keyValueTableRow('Ouverture', '-------------------------------'),
                  keyValueTableRow('Profondeur', '-------------------------------'),
                  keyValueTableRow('Nombre de travées', '-------------------------------'),
                  keyValueTableRow("Nombre de rangs", '-------------------------------'),
                  keyValueTableRow('Effectif admissible','-------------------------------'),
                  keyValueTableRow('Nombre de dégagements','-------------------------------'),
                  keyValueTableRow('Marque et modèle','-------------------------------'),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            pw.Center(child: pw.Text('VITESSE DU VENT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 10),

            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: 2)),
              child: pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(200),
                  1: const pw.FixedColumnWidth(100),
                },
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 2),
                ),
                children: [
                  keyValueTableRow('La vitesse du vent en exploitation est limitée à', _windSpeed.text.trim()),
                 ],
              ),
            ),
          ]);
        }

// Helper pour créer une ligne de document
        pw.TableRow _buildDocRow(String documentName, bool? isChecked) {
          return pw.TableRow(
            children: [
              pw.Container(
                padding: pw.EdgeInsets.all(8),
                child: pw.Text(
                  documentName,
                  style: pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.Container(
                padding: pw.EdgeInsets.all(8),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  isChecked == true ? 'X' : '',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Container(
                padding: pw.EdgeInsets.all(8),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  isChecked == false ? 'X' : '',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          );
        }

        pw.Widget docConsulte() {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'DOCUMENTS CONSULTÉS',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                ),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),  // Colonne large pour les documents
                    1: const pw.FixedColumnWidth(60), // Colonne OUI
                    2: const pw.FixedColumnWidth(60), // Colonne NON
                  },
                  border: pw.TableBorder.all(
                    color: PdfColors.black,
                    width: 2,
                  ),
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'TYPES DE DOCUMENTS',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'OUI',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'NON',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    ),

                    // Data rows
                    _buildDocRow('La notice technique du fabricant', checkboxValues[1]),
                    _buildDocRow('Plans de détail et de principe', checkboxValues[2]),
                    _buildDocRow('Notes de calculs', checkboxValues[3]),
                    _buildDocRow('Abaques de charges', checkboxValues[4]),
                    _buildDocRow('Avis technique sur modèle', checkboxValues[5]),
                    _buildDocRow('Avis sur dossier technique', checkboxValues[6]),
                    _buildDocRow('Étude de sol et capacité portante', checkboxValues[7]),
                    _buildDocRow('Avis de solidité', checkboxValues[8]),
                    _buildDocRow('Capacité portante du sol', checkboxValues[9]),
                    _buildDocRow('PV de classement au feu', checkboxValues[10]),
                    _buildDocRow('Attestation de bon montage', checkboxValues[11]),
                    _buildDocRow('Dossier de sécurité', checkboxValues[12]),
                    _buildDocRow('VGP des palans', checkboxValues[13]),
                  ],
                ),
              ),
            ],
          );
        }

        pw.TableRow _buildCatRow(String label, String valueForOs2) {
          pw.Widget emptyCell() => pw.Container(
                padding: pw.EdgeInsets.all(8),
                alignment: pw.Alignment.center,
                child: pw.Text('', style: pw.TextStyle(fontSize: 10)),
              );

          return pw.TableRow(
            children: [
              // Label column (Catégorie)
              pw.Container(
                padding: pw.EdgeInsets.all(8),
                child: pw.Text(
                  label,
                  style: pw.TextStyle(fontSize: 9),
                ),
              ),
              emptyCell(),// OP1
              emptyCell(), // OP2
              emptyCell(), // OP3
              emptyCell(), // OS1
              // OS2 (place the provided value here)
              pw.Container(
                padding: pw.EdgeInsets.all(8),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  valueForOs2,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
              // OS3
              emptyCell(),
            ],
          );
        }

        pw.Widget catEtPhoto() {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'Catégorisation',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),
                  pw.SizedBox(height: 10),

              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                ),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(60),  // Colonne large pour les documents
                    1: const pw.FixedColumnWidth(60), // Colonne OUI
                    2: const pw.FixedColumnWidth(60), // Colonne NON
                    3: const pw.FixedColumnWidth(60), // Colonne NON
                    4: const pw.FixedColumnWidth(60), // Colonne NON
                    5: const pw.FixedColumnWidth(60), // Colonne NON
                    6: const pw.FixedColumnWidth(60), // Colonne NON
                  },
                  border: pw.TableBorder.all(
                    color: PdfColors.black,
                    width: 2,
                  ),
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Catégorie',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'OP1',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'OP2',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'OP3',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'OS1',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'OS2',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'OS3',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    ),

                    // Data rows
                    _buildCatRow('Nombre', _nbStructures.text.trim()),
                   ],
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Center(
                child: pw.Text(
                  'PHOTO (VUE GÉNÉRALE) DE L\'ENSEMBLE DÉMONTABLE',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),

              // Building photo integration
              if (_buildingPhotoPath.isNotEmpty && File(_buildingPhotoPath).existsSync())
                pw.Container(
                  width: double.infinity,
                  height: 450,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
                    color: PdfColors.grey200,
                  ),
                 // clipBehavior: pw.Clip.antiAlias,
                  child: pw.Image(
                    pw.MemoryImage(File(_buildingPhotoPath).readAsBytesSync()),
                    fit: pw.BoxFit.cover,
                  ),
                ),

            ],
          );
        }

        pw.TableRow _buildVerifRow(String article, String pointExaminer, String observations, String noteObs) {
          // noteObs is expected to be one of: 'S', 'NS', 'SO', 'HM'. We mark the matching column with 'X'.
          String norm(String? v) => (v ?? '').trim().toUpperCase();
          final n = norm(noteObs);

          pw.Widget statusCell(String code) => pw.Container(
            padding: pw.EdgeInsets.all(8),
            alignment: pw.Alignment.center,
            child: pw.Text(n == code ? 'X' : '', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          );

          return pw.TableRow(
            children: [
              // ARTICLE
              pw.Container(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text(
                  article,
                  style: pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.center,

                ),
              ),
              // POINTS À EXAMINER
              pw.Container(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text(
                  pointExaminer,
                  style: pw.TextStyle(fontSize: 8),
                ),
              ),
              // OBSERVATIONS
              pw.Container(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text(
                  observations,
                  style: pw.TextStyle(fontSize: 9),
                ),
              ),
              // S
              statusCell('S'),
              // NS
              statusCell('NS'),
              // SO
              statusCell('SO'),
              // HM
              statusCell('HM'),
            ],
          );
        }

        // Split a long observations text into chunks to ensure no single table row grows beyond a page height.
        // Also handles very long strings without spaces by hard-splitting them.
        List<String> _splitIntoChunks(String text, {int maxChars = 60}) {
          final t = (text ?? '').trim();
          if (t.isEmpty) return [''];
          if (t.length <= maxChars) return [t];

          // First, break into tokens (words). If there are no spaces, words = [t].
          final rawTokens = t.split(RegExp(r'\s+'));
          final tokens = <String>[];

          // Ensure no single token exceeds maxChars by splitting long tokens.
          for (final tok in rawTokens) {
            if (tok.length <= maxChars) {
              tokens.add(tok);
            } else {
              for (int i = 0; i < tok.length; i += maxChars) {
                final end = (i + maxChars) < tok.length ? i + maxChars : tok.length;
                tokens.add(tok.substring(i, end));
              }
            }
          }
          //here also add the stuff necessary so it does not disappear on the next page and dtermine what is up here and whatever else is going on
          //oui and S NS HM SO

          // Now pack tokens into chunks not exceeding maxChars.
          final chunks = <String>[];
          var current = StringBuffer();
          for (final w in tokens) {
            final hasCurrent = current.isNotEmpty;
            final candidateLen = (hasCurrent ? current.length + 1 : 0) + w.length; // +1 for space
            if (candidateLen > maxChars) {
              if (hasCurrent) {
                chunks.add(current.toString());
                current = StringBuffer();
              }
              // If w itself is longer (it shouldn't be after token splitting), push as its own chunk.
              if (w.length > maxChars) {
                chunks.add(w);
              } else {
                current.write(w);
              }
            } else {
              if (hasCurrent) current.write(' ');
              current.write(w);
            }
          }
          if (current.isNotEmpty) {
            chunks.add(current.toString());
          }
          return chunks;
        }

        // Articles pour lesquels la case HM doit être remplie en noir par défaut
        final Set<String> _hmBlackArticles = {
         '3', '5', '7', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23',
          '26', '28', '32', '36','37','38','39','45', '47','48',
        };

        // Build one or more table rows for a verification entry, splitting long observations
        List<pw.TableRow> _buildVerifRows(String article, String pointExaminer, String observations, String noteObs) {
          String norm(String? v) => (v ?? '').trim().toUpperCase();
          final n = norm(noteObs);

          pw.Widget statusCell(String code, {bool enabled = true}) => pw.Container(
            padding: pw.EdgeInsets.all(8),
            alignment: pw.Alignment.center,
            child: enabled && n == code ? pw.Text('X', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)) : pw.SizedBox(),
          );

          final chunks = _splitIntoChunks(observations, maxChars: 600);
          final rows = <pw.TableRow>[];

          for (var i = 0; i < chunks.length; i++) {
            final isFirst = i == 0;
            rows.add(
              pw.TableRow(
                children: [
                  pw.Container(
                    padding: pw.EdgeInsets.all(3),
                    child: pw.Text(
                      isFirst ? article : '',
                      style: pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Container(
                    padding: pw.EdgeInsets.all(3),
                    child: pw.Text(
                      isFirst ? pointExaminer : '',
                      style: pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Container(
                    padding: pw.EdgeInsets.all(3),
                    child: pw.Text(
                      chunks[i],
                      style: pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  statusCell('S', enabled: isFirst),
                  statusCell('NS', enabled: isFirst),
                  statusCell('SO', enabled: isFirst),
                  _hmBlackArticles.contains(article) && isFirst
                      ? pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(color: PdfColors.black),
                        //  child: pw.SizedBox.expand(),
                        //  constraints: const pw.BoxConstraints(minHeight: 18, ),
                        )
                      : statusCell('HM', enabled: isFirst),
                ],
              ),
            );
          }
          return rows;
        }
        pw.TableRow _buildSectionHeaderRow(String title) {
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
            ),
            children: [
              // Première colonne (N°)
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.red, width: 3),
                    bottom: pw.BorderSide(color: PdfColors.red, width: 3),
                    left: pw.BorderSide(color: PdfColors.red, width: 3),
                    right: pw.BorderSide.none,
                  ),
                ),
              ),

              // Deuxième colonne (Articles)
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.red, width: 1),
                    bottom: pw.BorderSide(color: PdfColors.red, width: 1),
                    left: pw.BorderSide.none,
                    right: pw.BorderSide.none,
                  ),
                ),
              ),

              // Titre  (centré)
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                alignment: pw.Alignment.center,

                decoration: pw.BoxDecoration(

                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.red, width: 1),
                    bottom: pw.BorderSide(color: PdfColors.red, width: 1),
                    left: pw.BorderSide.none,
                    right: pw.BorderSide.none,
                  ),
                ),
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 9,

                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              // Colonnes S, NS, SO, HM (toutes sans bordures internes)
              ...List.generate(4, (index) => pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.black, width: 2),
                    bottom: pw.BorderSide(color: PdfColors.black, width: 2),
                    left: pw.BorderSide.none,
                    right: index == 3
                        ? pw.BorderSide(color: PdfColors.black, width: 2)  // Dernière colonne = bordure droite
                        : pw.BorderSide.none,
                  ),
                ),
              )),
            ],
          );
        }

        // Build the top header row (labels)
        pw.TableRow _buildTableHeaderRow({double cellPadding = 2}) {
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              pw.Container(
                padding: pw.EdgeInsets.all(cellPadding),
                child: pw.Text('ARTICLE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Container(
                padding: pw.EdgeInsets.all(cellPadding),
                child: pw.Text('POINTS À EXAMINER ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Container(
                padding: pw.EdgeInsets.all(cellPadding),
                child: pw.Text('OBSERVATIONS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              ),
              pw.Container(
                padding: pw.EdgeInsets.all(cellPadding),
                child: pw.Text('S', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              ),
              pw.Container(
                padding: pw.EdgeInsets.all(cellPadding),
                child: pw.Text('NS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              ),
              pw.Container(
                padding: pw.EdgeInsets.all(cellPadding),
                child: pw.Text('SO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              ),
              pw.Container(
                padding: pw.EdgeInsets.all(cellPadding),
                child: pw.Text('HM', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              ),
            ],
          );
        }

        // Render a single row as its own table to allow page breaks between rows
        pw.Widget _tableFromRow(pw.TableRow row, Map<int, pw.TableColumnWidth> widths, double borderWidth) {
          return pw.Table(
            columnWidths: widths,
            border: pw.TableBorder.all(color: PdfColors.black, width: borderWidth),
            children: [row],
          );
        }

        List<pw.Widget> _rowsToTables(List<pw.TableRow> rows, Map<int, pw.TableColumnWidth> widths, double borderWidth) {
          return rows.map((r) => _tableFromRow(r, widths, borderWidth)).toList();
        }

        // Multi-page friendly rendering of the first verification table
        pw.Widget verificationsMulti() {
          final widths = <int, pw.TableColumnWidth>{
            0: const pw.FixedColumnWidth(43),
            1: const pw.FixedColumnWidth(120),
            2: const pw.FixedColumnWidth(120),
            3: const pw.FixedColumnWidth(35),
            4: const pw.FixedColumnWidth(35),
            5: const pw.FixedColumnWidth(35),
            6: const pw.FixedColumnWidth(35),
          };
          const bw = 1.0;
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('TABLEAU DES VÉRIFICATIONS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              _tableFromRow(_buildTableHeaderRow(cellPadding: 2), widths, bw),
              _tableFromRow(_buildSectionHeaderRow('GÉNÉRALITÉS'), widths, bw),
              ..._rowsToTables(_buildVerifRows('3', 'Principes Généraux', _article3Obsrvt.text.trim(), checkboxValues2[3] ?? ''), widths, bw),
              ..._rowsToTables(_buildVerifRows('5', 'Adéquation de la capacité d\'acceuil', _article5Obsrvt.text.trim(), checkboxValues2[5] ?? ''), widths, bw),
              _tableFromRow(_buildSectionHeaderRow('IMPLANTATION'), widths, bw),
              ..._rowsToTables(_buildVerifRows('6', 'Lieu d\'implantation : voisinages dangereux et risques d\'inflammation', _article6Obsrvt.text.trim(), checkboxValues2[6] ?? ''), widths, bw),
              ..._rowsToTables(_buildVerifRows('7', 'Adéquation avec le sol : État du sol, calage, plaque de répartition...', _article7Obsrvt.text.trim(), checkboxValues2[7] ?? ''), widths, bw),
              _tableFromRow(_buildSectionHeaderRow('SOLIDITÉ'), widths, bw),
              ..._rowsToTables(_buildVerifRows('9', 'Marquage : Marque, modèle, année...', _article9Obsrvt.text.trim(), checkboxValues2[9] ?? ''), widths, bw),
              ..._rowsToTables(_buildVerifRows('10', 'Respect des charges d\'exploitation et charges climatiques', _article10Obsrvt.text.trim(), checkboxValues2[10] ?? ''), widths, bw),
              ..._rowsToTables(_buildVerifRows('11', 'Adéquation, état et assemblages des ossatures', _article11Obsrvt.text.trim(), checkboxValues2[11] ?? ''), widths, bw),
              _tableFromRow(_buildSectionHeaderRow('AMÉNAGEMENTS'), widths, bw),
              ..._rowsToTables(_buildVerifRows('12', 'Planchers : État, jeu, décalage...', _article12Obsrvt.text.trim(), checkboxValues2[12] ?? ''), widths, bw),
              ..._rowsToTables(_buildVerifRows('13', 'Contremarches : État, jeu, décalage...', _article13Obsrvt.text.trim(), checkboxValues2[13] ?? ''), widths, bw),
              ..._rowsToTables(_buildVerifRows('14', 'Places assises pour les gradins : Nombre, implantation...', _article14Obsrvt.text.trim(), checkboxValues2[14] ?? ''), widths, bw),
              ..._rowsToTables(_buildVerifRows('15', 'Places debout : Longueur et circulations', _article15Obsrvt.text.trim(), checkboxValues2[15] ?? ''), widths, bw),
              ..._rowsToTables(_buildVerifRows('16', 'Dégagements : Nombre, qualité, répartition et balisage', _article16Obsrvt.text.trim(), checkboxValues2[16] ?? ''), widths, bw),
              ..._rowsToTables(_buildVerifRows('17', 'Vomitoires et circulations : Configuration et projection', _article17Obsrvt.text.trim(), checkboxValues2[17] ?? ''), widths, bw),
              ..._rowsToTables(_buildVerifRows('18', 'Dessous : Inaccessibilité au public, potentiel calorifique...', _article18Obsrvt.text.trim(), checkboxValues2[18] ?? ''), widths, bw),
              ..._rowsToTables(_buildVerifRows('19', 'Escaliers et rampes accessibles au public : Qualité, état, assemblage...', _article19Obsrvt.text.trim(), checkboxValues2[19] ?? ''), widths, bw),
              ..._rowsToTables(_buildVerifRows('20', 'Garde-corps : Qualité, état, assemblage...', _article20Obsrvt.text.trim(), checkboxValues2[20] ?? ''), widths, bw),
              ..._rowsToTables(_buildVerifRows('21', 'Sièges et bancs fixes : Qualité, état, assemblage...', _article21Obsrvt.text.trim(), checkboxValues2[21] ?? ''), widths, bw),
              ..._rowsToTables(_buildVerifRows('22', 'Sièges et banc non fixes : Nombre', _article22Obsrvt.text.trim(), checkboxValues2[22] ?? ''), widths, bw),
              ..._rowsToTables(_buildVerifRows('23', 'Sièges : Caractéristiques, PV de réaction au feu...', _article23Obsrvt.text.trim(), checkboxValues2[23] ?? ''), widths, bw),


              ..._rowsToTables(_buildVerifRows('24', 'Barrière anti-renversement : Présence, état, assemblage...', _article24Obsrvt.text.trim(), checkboxValues2[24] ?? ''), widths, bw),

              _tableFromRow(_buildSectionHeaderRow('EXPLOITATION'), widths, bw),

              ..._rowsToTables(_buildVerifRows('25', '25. Impact sur le niveau de sécurité du lieu', _article25Obsrvt.text.trim(), checkboxValues2[25] ?? ''),widths, bw),
          ..._rowsToTables(_buildVerifRows('26', '26. Examen d\'adéquation, accroches, accessoires de levage, moyens de levage (type de palan, sécurisation, redondance, etc.), rapport de VGP', _article26Obsrvt.text.trim(), checkboxValues2[26] ?? ''),widths, bw),
          ..._rowsToTables(_buildVerifRows('27', '27. Habillages : PV de réaction au feu, état, assemblage...', _article27Obsrvt.text.trim(), checkboxValues2[27] ?? ''),widths, bw),
          ..._rowsToTables(_buildVerifRows('28', '28. Cas des passerelles ne servant pas d\'espace d\'observation : bardage sur 2m de hauteur', _article28Obsrvt.text.trim(), checkboxValues2[28] ?? ''),widths, bw),
          ..._rowsToTables(_buildVerifRows('29', '29. Câbles électriques : absence d\'entrave à la circulation des personnes / Installations électriques : présence du plan avec localisation des dispositifs de coupure d\'urgence', _article29Obsrvt.text.trim(), checkboxValues2[29] ?? ''),widths, bw),
          ..._rowsToTables(_buildVerifRows('30', '30. Présence du rapport de vérification des installations électriques', _article30Obsrvt.text.trim(), checkboxValues2[30] ?? ''),widths, bw),
          ..._rowsToTables(_buildVerifRows('31', '31. Éclairage de sécurité en adéquation avec les conditions d\'exploitation', _article31bsrvt.text.trim(), checkboxValues2[31] ?? ''),widths, bw),
          ..._rowsToTables(_buildVerifRows('32', '32. Anémomètre (plein air) : Présence, implantation et fonctionnement / Modalités d\'évacuation', _article32bsrvt.text.trim(), checkboxValues2[32] ?? ''),widths, bw),
          ..._rowsToTables(_buildVerifRows('33', '33. Diffusion de l\'alarme et de l\'alerte', _article33bsrvt.text.trim(), checkboxValues2[33] ?? ''),widths, bw),
          ..._rowsToTables(_buildVerifRows('34', '34. Moyens d\'extinction', _article34bsrvt.text.trim(), checkboxValues2[34] ?? ''),widths, bw),
              _tableFromRow(_buildSectionHeaderRow('CONTRÔLE, VERIFICATION ET INSPECTION'), widths, bw),
              ..._rowsToTables(_buildVerifRows('36', '36. Notices techniques : Présence', _article36bsrvt.text.trim(), checkboxValues2[36] ?? ''),widths, bw),
          ..._rowsToTables(_buildVerifRows('37', '37. Conception : Présence d\'un avis sur modèle type ou sur dossier technique', _article37bsrvt.text.trim(), checkboxValues2[37] ?? ''),widths, bw),
          ..._rowsToTables(_buildVerifRows('38', '38. Attestation de bon montage : Présence', _article38bsrvt.text.trim(), checkboxValues2[38] ?? ''),widths, bw),
          ..._rowsToTables(_buildVerifRows('39', '39. Dossier de sécurité : Présence et cohérence', _article39bsrvt.text.trim(), checkboxValues2[39] ?? ''),widths, bw),
              _tableFromRow(_buildSectionHeaderRow('IMPLANTATION PROLONGÉE'), widths, bw),
              ..._rowsToTables(_buildVerifRows('45', '45. État de conservation', _article45bsrvt.text.trim(), checkboxValues2[45] ?? ''),widths, bw),
              _tableFromRow(_buildSectionHeaderRow('ENSEMBLE DÉMONTABLE EXISTANT'), widths, bw),
              ..._rowsToTables(_buildVerifRows('47', '47. Solidité et stabilité : Présence de documents', _article47bsrvt.text.trim(), checkboxValues2[47] ?? ''),widths, bw),
          ..._rowsToTables(_buildVerifRows('48', '48. Marquage', _article48bsrvt.text.trim(), checkboxValues2[48] ?? ''),widths, bw),

            ],
          );
        }

        pw.Widget verifications() {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'TABLEAU DES VÉRIFICATIONS',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(43),  // Colonne large pour les documents
                  1: const pw.FixedColumnWidth(120), // Colonne OUI
                  2: const pw.FixedColumnWidth(120), // Colonne NON
                  3: const pw.FixedColumnWidth(35), // Colonne NON
                  4: const pw.FixedColumnWidth(35), // Colonne NON
                  5: const pw.FixedColumnWidth(35), // Colonne NON
                  6: const pw.FixedColumnWidth(35), // Colonne NON
                },
                border: pw.TableBorder.all(
                  color: PdfColors.black,
                  width: 1,
                ),
                children: [
                    // Header row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Container(
                          padding: pw.EdgeInsets.all(2),
                          child: pw.Text(
                            'ARTICLE',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(2),
                          child: pw.Text(
                            'POINTS À EXAMINER ',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(2),
                          child: pw.Text(
                            'OBSERVATIONS',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(2),
                          child: pw.Text(
                            'S',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(2),
                          child: pw.Text(
                            'NS',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(2),
                          child: pw.Text(
                            'SO',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(2),
                          child: pw.Text(
                            'HM',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    ),

                    _buildSectionHeaderRow('GÉNÉRALITÉS'),

                    ..._buildVerifRows('3', 'Principes Généraux', _article3Obsrvt.text.trim(), checkboxValues2[3] ?? ''),
                    ..._buildVerifRows('5', 'Adéquation de la capacité d\'acceuil', _article5Obsrvt.text.trim(), checkboxValues2[5] ?? ''),
                    _buildSectionHeaderRow('IMPLANTATION'),

                    ..._buildVerifRows('6', 'Lieu d\'implantation : voisinages dangereux et risques d\'inflammation', _article6Obsrvt.text.trim(), checkboxValues2[6] ?? ''),
                    ..._buildVerifRows('7', 'Adéquation avec le sol : État du sol, calage, plaque de répartition...', _article7Obsrvt.text.trim(), checkboxValues2[7] ?? ''),
                    _buildSectionHeaderRow('SOLIDITÉ'),

                    ..._buildVerifRows('9', 'Marquage : Marque, modèle, année...', _article9Obsrvt.text.trim(), checkboxValues2[9] ?? ''),
                    ..._buildVerifRows('10', 'Respect des charges d\'exploitation et charges climatiques', _article10Obsrvt.text.trim(), checkboxValues2[10] ?? ''),
                    ..._buildVerifRows('11', 'Adéquation, état et assemblages des ossatures', _article11Obsrvt.text.trim(), checkboxValues2[11] ?? ''),
                    _buildSectionHeaderRow('AMÉNAGEMENTS'),
                    ..._buildVerifRows('12', 'Planchers : État, jeu, décalage...', _article12Obsrvt.text.trim(), checkboxValues2[12] ?? ''),
                    ..._buildVerifRows('13', 'Contremarches : État, jeu, décalage...', _article13Obsrvt.text.trim(), checkboxValues2[13] ?? ''),
                    ..._buildVerifRows('14', 'Places assises pour les gradins : Nombre, implantation...', _article14Obsrvt.text.trim(), checkboxValues2[14] ?? ''),
                    ..._buildVerifRows('15', 'Places debout : Longueur et circulations', _article15Obsrvt.text.trim(), checkboxValues2[15] ?? ''),
                    ..._buildVerifRows('16', 'Dégagements : Nombre, qualité, répartition et balisage', _article16Obsrvt.text.trim(), checkboxValues2[16] ?? ''),
                    ..._buildVerifRows('17', 'Vomitoires et circulations : Configuration et projection', _article17Obsrvt.text.trim(), checkboxValues2[17] ?? ''),
                    ..._buildVerifRows('18', 'Dessous : Inaccessibilité au public, potentiel calorifique...', _article18Obsrvt.text.trim(), checkboxValues2[18] ?? ''),
                    ..._buildVerifRows('19', 'Escaliers et rampes accessibles au public : Qualité, état, assemblage...', _article19Obsrvt.text.trim(), checkboxValues2[19] ?? ''),
                    ..._buildVerifRows('20', 'Garde-corps : Qualité, état, assemblage...', _article20Obsrvt.text.trim(), checkboxValues2[20] ?? ''),
                    ..._buildVerifRows('21', 'Sièges et bancs fixes : Qualité, état, assemblage...', _article21Obsrvt.text.trim(), checkboxValues2[21] ?? ''),
                    ..._buildVerifRows('22', 'Sièges et banc non fixes : Nombre', _article22Obsrvt.text.trim(), checkboxValues2[22] ?? ''),
                    ..._buildVerifRows('23', 'Sièges : Caractéristiques, PV de réaction au feu...', _article23Obsrvt.text.trim(), checkboxValues2[23] ?? ''),

              //      _buildVerifRow('24', 'Barrière anti-renversement : Présence, état, assemblage...', _article24Obsrvt.text.trim(), checkboxValues2[24] ?? ''),





                  ],

                ),
              pw.SizedBox(height: 10),



            ],
          );
        }

        pw.Widget verifications2() {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'TABLEAU DES VÉRIFICATIONS',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(55),  // Colonne large pour les documents
                  1: const pw.FixedColumnWidth(120), // Colonne OUI
                  2: const pw.FixedColumnWidth(120), // Colonne NON
                  3: const pw.FixedColumnWidth(35), // Colonne NON
                  4: const pw.FixedColumnWidth(35), // Colonne NON
                  5: const pw.FixedColumnWidth(35), // Colonne NON
                  6: const pw.FixedColumnWidth(35), // Colonne NON
                },
                border: pw.TableBorder.all(
                  color: PdfColors.black,
                    width: 2,
                  ),
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'ARTICLE',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'POINTS À EXAMINER ',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'OBSERVATIONS',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'S',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'NS',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'SO',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'HM',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    ),



                    ..._buildVerifRows('25', '25. Impact sur le niveau de sécurité du lieu', _article25Obsrvt.text.trim(), checkboxValues2[25] ?? ''),
                    ..._buildVerifRows('26', '26. Examen d\'adéquation, accroches, accessoires de levage, moyens de levage (type de palan, sécurisation, redondance, etc.), rapport de VGP', _article26Obsrvt.text.trim(), checkboxValues2[26] ?? ''),
                    ..._buildVerifRows('27', '27. Habillages : PV de réaction au feu, état, assemblage...', _article27Obsrvt.text.trim(), checkboxValues2[27] ?? ''),
                    ..._buildVerifRows('28', '28. Cas des passerelles ne servant pas d\'espace d\'observation : bardage sur 2m de hauteur', _article28Obsrvt.text.trim(), checkboxValues2[28] ?? ''),
   /*                 _buildVerifRow('29', '29. Câbles électriques : absence d\'entrave à la circulation des personnes / Installations électriques : présence du plan avec localisation des dispositifs de coupure d\'urgence', _article29Obsrvt.text.trim(), checkboxValues2[29] ?? ''),
                    ..._buildVerifRows('30', '30. Présence du rapport de vérification des installations électriques', _article30Obsrvt.text.trim(), checkboxValues2[30] ?? ''),
                    _buildVerifRow('31', '31. Éclairage de sécurité en adéquation avec les conditions d\'exploitation', _article31bsrvt.text.trim(), checkboxValues2[31] ?? ''),


 */
            /*        _buildVerifRow('32', '32. Anémomètre (plein air) : Présence, implantation et fonctionnement / Modalités d\'évacuation', _article32bsrvt.text.trim(), checkboxValues2[32] ?? ''),
                    _buildVerifRow('33', '33. Diffusion de l\'alarme et de l\'alerte', _article33bsrvt.text.trim(), checkboxValues2[33] ?? ''),
                    _buildVerifRow('34', '34. Moyens d\'extinction', _article34bsrvt.text.trim(), checkboxValues2[34] ?? ''),
                    _buildVerifRow('36', '36. Notices techniques : Présence', _article36bsrvt.text.trim(), checkboxValues2[36] ?? ''),
                    _buildVerifRow('37', '37. Conception : Présence d\'un avis sur modèle type ou sur dossier technique', _article37bsrvt.text.trim(), checkboxValues2[37] ?? ''),
                    _buildVerifRow('38', '38. Attestation de bon montage : Présence', _article38bsrvt.text.trim(), checkboxValues2[38] ?? ''),
                    _buildVerifRow('39', '39. Dossier de sécurité : Présence et cohérence', _article39bsrvt.text.trim(), checkboxValues2[39] ?? ''),
                    _buildVerifRow('45', '45. État de conservation', _article45bsrvt.text.trim(), checkboxValues2[45] ?? ''),
                    _buildVerifRow('47', '47. Solidité et stabilité : Présence de documents', _article47bsrvt.text.trim(), checkboxValues2[47] ?? ''),
                    _buildVerifRow('48', '48. Marquage', _article48bsrvt.text.trim(), checkboxValues2[48] ?? ''),



             */
                  ],

                ),
              pw.SizedBox(height: 10),



            ],
          );
        }



        // Build the top header row (labels)
        pw.TableRow _buildTableHeaderRowObs({double cellPadding = 2}) {
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              pw.Container(
                padding: pw.EdgeInsets.all(cellPadding),
                child: pw.Text('N°', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Container(
                padding: pw.EdgeInsets.all(cellPadding),
                child: pw.Text('DÉTAILS DE L\'OBSERVATION ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Container(
                padding: pw.EdgeInsets.all(cellPadding),
                child: pw.Text('ARTICLE DE RÉFÉRENCE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              ),
              pw.Container(
                padding: pw.EdgeInsets.all(cellPadding),
                child: pw.Text('N° PHOTO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
              ),

            ],
          );
        }

        // Render a single row as its own table to allow page breaks between rows
        pw.Widget _tableFromRowObs(pw.TableRow row, Map<int, pw.TableColumnWidth> widths, double borderWidth) {
          return pw.Table(
            columnWidths: widths,
            border: pw.TableBorder.all(color: PdfColors.black, width: borderWidth),
            children: [row],
          );
        }

        List<pw.Widget> _rowsToTablesObs(List<pw.TableRow> rows, Map<int, pw.TableColumnWidth> widths, double borderWidth) {
          return rows.map((r) => _tableFromRowObs(r, widths, borderWidth)).toList();
        }

        String _getObsCommentForArticle(int i) {
          switch (i) {
            case 3:
              return _article3Obsrvt.text.trim();
            case 5:
              return _article5Obsrvt.text.trim();
            case 6:
              return _article6Obsrvt.text.trim();
            case 7:
              return _article7Obsrvt.text.trim();
            case 9:
              return _article9Obsrvt.text.trim();
            case 10:
              return _article10Obsrvt.text.trim();
            case 11:
              return _article11Obsrvt.text.trim();
            case 12:
              return _article12Obsrvt.text.trim();
            case 13:
              return _article13Obsrvt.text.trim();
            case 14:
              return _article14Obsrvt.text.trim();
            case 15:
              return _article15Obsrvt.text.trim();
            case 16:
              return _article16Obsrvt.text.trim();
            case 17:
              return _article17Obsrvt.text.trim();
            case 18:
              return _article18Obsrvt.text.trim();
            case 19:
              return _article19Obsrvt.text.trim();
            case 20:
              return _article20Obsrvt.text.trim();
            case 21:
              return _article21Obsrvt.text.trim();
            case 22:
              return _article22Obsrvt.text.trim();
            case 23:
              return _article23Obsrvt.text.trim();
            case 24:
              return _article24Obsrvt.text.trim();
            case 25:
              return _article25Obsrvt.text.trim();
            case 26:
              return _article26Obsrvt.text.trim();
            case 27:
              return _article27Obsrvt.text.trim();
            case 28:
              return _article28Obsrvt.text.trim();
            case 29:
              return _article29Obsrvt.text.trim();
            case 30:
              return _article30Obsrvt.text.trim();
            case 31:
              return _article31bsrvt.text.trim();
            case 32:
              return _article32bsrvt.text.trim();
            case 33:
              return _article33bsrvt.text.trim();
            case 34:
              return _article34bsrvt.text.trim();
            case 36:
              return _article36bsrvt.text.trim();
            case 37:
              return _article37bsrvt.text.trim();
            case 38:
              return _article38bsrvt.text.trim();
            case 39:
              return _article39bsrvt.text.trim();
            case 45:
              return _article45bsrvt.text.trim();
            case 47:
              return _article47bsrvt.text.trim();
            case 48:
              return _article48bsrvt.text.trim();
            default:
              return '';
          }
        }

        List<pw.TableRow> _buildObsRowsFromNS() {
          final rows = <pw.TableRow>[];
          int obsIndex = 1;
          for (int i = 1; i <= 48; i++) {
            if (checkboxValues2[i] == 'NS') {
              final obsComment =  _getObsCommentForArticle(i);
              rows.add(
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(2),
                      child: pw.Text(obsIndex.toString(), style: pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(2),
                      child: pw.Text(obsComment, style: pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(2),
                      child: pw.Text('Article ' + i.toString(), style: pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
                    ),
                    pw.Container(
                      padding: pw.EdgeInsets.all(2),
                      child: pw.Text(obsIndex.toString(), style: pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
                    ),
                  ],
                ),
              );
              obsIndex++;
            }
          }
          return rows;
        }

        pw.Widget rappelObs() {
          final widths = <int, pw.TableColumnWidth>{
            0: const pw.FixedColumnWidth(20),
            1: const pw.FixedColumnWidth(250),
            2: const pw.FixedColumnWidth(50),
            3: const pw.FixedColumnWidth(40),

          };
          const bw = 1.0;
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('Rappel des Observations', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              _tableFromRowObs(_buildTableHeaderRowObs(cellPadding: 2), widths, bw),
              ..._rowsToTablesObs(_buildObsRowsFromNS(), widths, bw),
            ],
          );
        }

// Build the top header row (labels)
        pw.TableRow _buildTableHeaderRowObsPhotos({double cellPadding = 2}) {
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              pw.Container(
                padding: pw.EdgeInsets.all(cellPadding),
                child: pw.Text('Photos des Articles Non Satisfaisant', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),

            ],
          );
        }

        // Render a single row as its own table to allow page breaks between rows
        pw.Widget _tableFromRowObsPhotos(pw.TableRow row, Map<int, pw.TableColumnWidth> widths, double borderWidth) {
          return pw.Table(
            columnWidths: widths,
            border: pw.TableBorder.all(color: PdfColors.black, width: borderWidth),
            children: [row],
          );
        }

        List<pw.Widget> _rowsToTablesObsPhotos(List<pw.TableRow> rows, Map<int, pw.TableColumnWidth> widths, double borderWidth) {
          return rows.map((r) => _tableFromRowObsPhotos(r, widths, borderWidth)).toList();
        }

        String _getObsCommentForArticlePhotos(int i) {
          switch (i) {
            case 3:
              return _article3Photo.text.trim();
              /*
            case 5:
              return _article5Photo.text.trim();

               */
              /*
            case 6:
              return _article6Obsrvt.text.trim();
            case 7:
              return _article7Obsrvt.text.trim();
            case 9:
              return _article9Obsrvt.text.trim();
            case 10:
              return _article10Obsrvt.text.trim();
            case 11:
              return _article11Obsrvt.text.trim();
            case 12:
              return _article12Obsrvt.text.trim();
            case 13:
              return _article13Obsrvt.text.trim();
            case 14:
              return _article14Obsrvt.text.trim();
            case 15:
              return _article15Obsrvt.text.trim();
            case 16:
              return _article16Obsrvt.text.trim();
            case 17:
              return _article17Obsrvt.text.trim();
            case 18:
              return _article18Obsrvt.text.trim();
            case 19:
              return _article19Obsrvt.text.trim();
            case 20:
              return _article20Obsrvt.text.trim();
            case 21:
              return _article21Obsrvt.text.trim();
            case 22:
              return _article22Obsrvt.text.trim();
            case 23:
              return _article23Obsrvt.text.trim();
            case 24:
              return _article24Obsrvt.text.trim();
            case 25:
              return _article25Obsrvt.text.trim();
            case 26:
              return _article26Obsrvt.text.trim();
            case 27:
              return _article27Obsrvt.text.trim();
            case 28:
              return _article28Obsrvt.text.trim();
            case 29:
              return _article29Obsrvt.text.trim();
            case 30:
              return _article30Obsrvt.text.trim();
            case 31:
              return _article31bsrvt.text.trim();
            case 32:
              return _article32bsrvt.text.trim();
            case 33:
              return _article33bsrvt.text.trim();
            case 34:
              return _article34bsrvt.text.trim();
            case 36:
              return _article36bsrvt.text.trim();
            case 37:
              return _article37bsrvt.text.trim();
            case 38:
              return _article38bsrvt.text.trim();
            case 39:
              return _article39bsrvt.text.trim();
            case 45:
              return _article45bsrvt.text.trim();
            case 47:
              return _article47bsrvt.text.trim();
            case 48:
              return _article48bsrvt.text.trim();

               */
            default:
              return '';
          }
        }

        List<pw.TableRow> _buildObsRowsFromNSPhotos() {
          final rows = <pw.TableRow>[];
          for (int i = 1; i <= 48; i++) {
            if (checkboxValues2[i] == 'NS') {
              final obsComment = _getObsCommentForArticle(i);
              final SubPhotoEntry? photo = _articlePhotos[i];

              pw.Widget imageWidget;
              if (photo != null && photo.imagePath.isNotEmpty) {
                try {
                  final bytes = File(photo.imagePath).readAsBytesSync();
                  imageWidget = pw.Image(
                    pw.MemoryImage(bytes),
                    width: 350,
                    height: 220,
                    fit: pw.BoxFit.contain,
                  );
                } catch (_) {
                  imageWidget = pw.Text('Photo non disponible', style: const pw.TextStyle(fontSize: 9));
                }
              } else {
                imageWidget = pw.Text('Aucune photo associée', style: const pw.TextStyle(fontSize: 9));
              }

              rows.add(
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Article $i: ${obsComment.isNotEmpty ? obsComment : 'Sans description'}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 6),
                          imageWidget,
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
          }
          return rows;
        }

        pw.Widget rappelObsPhotos() {
          final widths = <int, pw.TableColumnWidth>{
            0: const pw.FixedColumnWidth(100),
            1: const pw.FixedColumnWidth(250),
            2: const pw.FixedColumnWidth(50),
            3: const pw.FixedColumnWidth(40),

          };
          const bw = 1.0;
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('Photos des Articles Non Satisfaisant', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              _tableFromRowObsPhotos(_buildTableHeaderRowObsPhotos(cellPadding: 2), widths, bw),
              ..._rowsToTablesObsPhotos(_buildObsRowsFromNSPhotos(), widths, bw),
            ],
          );
        }

// Fonction helper pour créer une ligne d'avis avec case à cocher
        pw.TableRow keyValueAvisRow(String label, bool isChecked) {
          return pw.TableRow(
            children: [
              // Colonne label avec fond gris
              pw.Container(
                padding: pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  border: pw.Border(
                    right: pw.BorderSide(color: PdfColors.grey700, width: 1.5),
                  ),
                ),
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              // Colonne valeur: case à cocher
              pw.Container(
                padding: pw.EdgeInsets.all(8),
                child: pw.Container(
                  width: 12,
                  height: 12,

                  child: isChecked
                      ? pw.Center(
                          child: pw.Text(
                            'X',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                          ),
                        )
                      : null,
                ),
              ),
            ],
          );
        }

// Dans votre fonction qui retourne les avis
        pw.Widget avisFinal() {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Titre (optionnel)
              pw.Text(
                'AVIS FINAL',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),

              // Tableau Avis Favorable
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey700, width: 2),
                ),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FixedColumnWidth(100),
                    1: const pw.FixedColumnWidth(50),
                  },
                  border: pw.TableBorder(
                    horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 2),
                  ),
                  children: [
                    keyValueAvisRow('Avis Favorable', checkboxValues[1] == true),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // Tableau Avis Défavorable
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey700, width: 2),
                ),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FixedColumnWidth(100),
                    1: const pw.FixedColumnWidth(50),
                  },
                  border: pw.TableBorder(
                    horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 2),
                  ),
                  children: [
                    keyValueAvisRow('Avis Défavorable', checkboxValues[1] == false),
                  ],
                ),
              ),
            ],
          );
        }

        // Helper to prebuild signature table row with image if available
        Future<pw.TableRow> _buildSignatureTableRow() async {
          final labelCell = pw.Container(
            padding: const pw.EdgeInsets.all(2),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              border: pw.Border(
                right: pw.BorderSide(color: PdfColors.grey700, width: 1.2),
              ),
            ),
            child: pw.Text('Signature\n', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          );

          pw.Widget valueChild;
          try {
            if (_signatureBytes != null && _signatureBytes!.isNotEmpty) {
              valueChild = pw.Image(pw.MemoryImage(_signatureBytes!), width: 60, height: 40, fit: pw.BoxFit.contain);
            } else if (_signaturePath.isNotEmpty && await File(_signaturePath).exists()) {
              final bytes = await File(_signaturePath).readAsBytes();
              valueChild = pw.Image(pw.MemoryImage(bytes), width: 60, height: 40, fit: pw.BoxFit.contain);
            } else {
              valueChild = pw.Text('-', style: const pw.TextStyle(fontSize: 10));
            }
          } catch (_) {
            valueChild = pw.Text('-', style: const pw.TextStyle(fontSize: 10));
          }

          final valueCell = pw.Container(
            padding: const pw.EdgeInsets.all(6),
            child: valueChild,
          );

          return pw.TableRow(children: [labelCell, valueCell]);
        }

        pw.Widget tableauConclu(pw.TableRow signatureRow) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Tableau de conclusion
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey700, width: 2),
                ),
                child: pw.Table(
                  columnWidths: {
                    0: const pw.FixedColumnWidth(100),
                    1: const pw.FixedColumnWidth(50),
                  },
                  border: pw.TableBorder(
                    horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 2),
                  ),
                  children: [
                    keyValueTableRow('Fait à', _siteName.text.trim() ),
                    keyValueTableRow('Le (date et heure', _dateTransmission.text.trim() ),
                    keyValueTableRow('Par', _techName.text.trim() ),
                    signatureRow,
                  ],
                ),
              ),
            ],
          );
        }

        // Pre-build async sections before adding the page because pw.MultiPage.build must be synchronous
    //    final pw.Widget anomaliesSectionWidget = await anomaliesSection();
        final pw.TableRow signatureTableRow = await _buildSignatureTableRow();


          // Helper to add all report pages to the given document. Optionally overrides total pages in the info table
          void _addReportPages(pw.Document doc, {int? totalPagesOverride, void Function(int)? onComputed}) {
            doc.addPage(
              pw.MultiPage(
                pageFormat: PdfPageFormat.a4,
                margin: pw.EdgeInsets.zero,  // ← Pas de marge pour la page
                header: (context) {
                  return pw.Container(
                    width: double.infinity,
                    padding: pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: buildHeader(context),  // Header en pleine largeur
                  );
                },
                footer: (context) {
                  // Capture total pages when available during layout
                  if (onComputed != null && context.pagesCount > 0) {
                    onComputed(context.pagesCount);
                  }
                  return pw.Container(
                    width: double.infinity,
                    padding: pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: buildFooter(context),  // Footer en pleine largeur
                  );
                },
                build: (pw.Context context) => [
                  pw.Padding(
                    padding: pw.EdgeInsets.fromLTRB(90, 72, 90, 20),  // ← Marges uniquement pour le contenu
                    child: pw.Column(
                      children: [
                        infoTablePage(context, totalPagesOverride: totalPagesOverride),
                      ],
                    ),
                  ),
                  pw.NewPage(),

                  pw.Padding(
                    padding: pw.EdgeInsets.fromLTRB(90, 20, 90, 20),
                    child: preambulePage(),
                  ),

                  pw.SizedBox(height: 16),
                  pw.NewPage(),
                  pw.Padding(
                    padding: pw.EdgeInsets.fromLTRB(90, 20, 90, 20),
                    child: referentielPage(),
                  ),
                  pw.NewPage(),

                  pw.Padding(
                    padding: pw.EdgeInsets.fromLTRB(90, 20, 90, 20),
                    child: renseignements(),
                  ),
                  pw.NewPage(),

                  pw.Padding(
                    padding: pw.EdgeInsets.fromLTRB(90, 20, 90, 20),
                    child: renseignements2(),
                  ),

                  pw.NewPage(),

                  pw.Padding(
                    padding: pw.EdgeInsets.fromLTRB(90, 20, 90, 20),
                    child: renseignements3(),
                  ),
                  pw.NewPage(),

                  pw.Padding(
                    padding: pw.EdgeInsets.fromLTRB(90, 20, 90, 20),
                    child: docConsulte(),
                  ),
                  pw.NewPage(),

                  pw.Padding(
                    padding: pw.EdgeInsets.fromLTRB(90, 20, 90, 20),
                    child: catEtPhoto(),
                  ),
                  pw.NewPage(),
                  pw.Padding(
                    padding: pw.EdgeInsets.fromLTRB(45, 20, 45, 20),
                    child: verificationsMulti(),
                  ),

                  pw.NewPage(),

                  pw.Padding(
                    padding: pw.EdgeInsets.fromLTRB(50, 20, 50, 20),
                    child: rappelObs(),
                  ),
                  pw.NewPage(),

                  pw.Padding(
                    padding: pw.EdgeInsets.fromLTRB(50, 20, 50, 20),
                    child: rappelObsPhotos(),
                  ),
                  pw.NewPage(),

                  pw.Padding(
                    padding: pw.EdgeInsets.fromLTRB(180, 20, 180, 20),
                    child: avisFinal(),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.fromLTRB(90, 20, 90, 20),
                    child: tableauConclu(signatureTableRow),
                  ),
                ],
              ),
            );
          }

          // First pass: build a draft to compute the total number of pages
          int _computedTotalPages = 0;
          final pdfDraft = pw.Document();
          _addReportPages(pdfDraft, onComputed: (n) {
            if (n > _computedTotalPages) _computedTotalPages = n;
          });
          // Saving triggers layout and computes page count
          await pdfDraft.save();

          // Second pass: build the final document with the computed total pages injected
          _addReportPages(pdf, totalPagesOverride: _computedTotalPages);

        if (kIsWeb) {
          final bytes = await pdf.save();
          setState(() {
            _lastGeneratedPdfBytes = bytes;
            _lastGeneratedPdfPath = '';
          });
          return 'memory';
        }
        final dir = await getApplicationDocumentsDirectory();
        final safeRef = ref.isNotEmpty ? ref.replaceAll(' ', '_') : 'VE';
        final filePath = '${dir.path}/rapport_${safeRef}_$dateStr.pdf';
        final file = File(filePath);
        await file.writeAsBytes(await pdf.save());

        setState(() {
          _lastGeneratedPdfPath = filePath;
        });
        return filePath;
      } catch (e) {
        rethrow;
      }
    }

    Future<void> _showPdfPreview() async {
      try {
        if (kIsWeb) {
          if (_lastGeneratedPdfBytes == null || _lastGeneratedPdfBytes!.isEmpty) {
            await _generatePdfFromData();
          }
          if (_lastGeneratedPdfBytes == null || _lastGeneratedPdfBytes!.isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Aucun PDF généré.')),
            );
            return;
          }
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PdfPreviewScreen(
                pdfBuilder: (format) async => _lastGeneratedPdfBytes!,
              ),
            ),
          );
          return;
        }

        if (_lastGeneratedPdfPath.isEmpty) {
          await _generatePdfFromData();
        }
        if (_lastGeneratedPdfPath.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Aucun PDF généré.')),
          );
          return;
        }
        final path = _lastGeneratedPdfPath;
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBuilder: (format) async => await File(path).readAsBytes(),
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'aperçu PDF: $e')),
        );
      }
    }

    Future<void> _sendEmailWithAttachment({bool preview = false}) async {
      if (_lastGeneratedDocPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez d\'abord générer le document')),
        );
        return;
      }

      try {

        if (preview) {
          // Try to open the generated document for a quick preview
          await OpenFilex.open(_lastGeneratedDocPath);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('👁️ Aperçu ouvert: ${_lastGeneratedDocPath}'),
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Saved: ${_lastGeneratedDocPath}'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        // Generate a PDF version automatically before sending
        await _generatePdfFromData();
        final String attachmentPath = _lastGeneratedPdfPath.isNotEmpty ? _lastGeneratedPdfPath : _lastGeneratedDocPath;

        final recipientEmail = _mailStand.text.trim();
        final String recipient = recipientEmail.isNotEmpty ? recipientEmail : 'client@example.com';

        final subject = 'Rapport de Vérification Après Montage: ${_salonName.text} Hall ${_standHall.text} - Stand: ${_standName.text} ${_standNb.text}';
        final body = 'Bonjour,\n\n'
            'Veuillez trouver ci-joint le rapport de vérification après montage demandé.\n\n'
            'Date: ${_dateTransmission.text}\n'
            'Salon: ${_salonName.text}\n'
            'Hall: ${_standHall.text}\n'
            'Stand: ${_standName.text} ${_standNb.text}\n\n'
            'Cordialement,\n'
            '${_techName.text},\n'
            'Versant Event.';

        final Email email = Email(
          body: body,
          subject: subject,
          recipients: [recipient],
          cc: ['contact@versantevenement.com'],
          attachmentPaths: [attachmentPath],
          isHTML: false,
        );

        // Essayer d'abord avec flutter_email_sender
        try {
          await FlutterEmailSender.send(email);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Email envoyé à $recipient'),
              backgroundColor: Colors.green,
            ),
          );
        } on PlatformException catch (e) {
          if (e.code == 'not_available') {
            // Fallback vers Share si aucun client email
            if (!mounted) return;

            final result = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: blackAmont,
                title: Text('Aucun client email', style: TextStyle(color: blanc)),
                content: Text(
                  'Aucun client email trouvé.\n\n'
                      'Voulez-vous utiliser le partage à la place?',
                  style: TextStyle(color: blanc),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Annuler', style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Partager', style: TextStyle(color: bleuAmont)),
                  ),
                ],
              ),
            );

            if (result == true) {
              final ref = _nosReferences.text.trim();
              await Share.shareXFiles(
                [
                  XFile(
                    _lastGeneratedPdfPath.isNotEmpty ? _lastGeneratedPdfPath : attachmentPath,
                    mimeType: 'application/pdf',
                    name: 'rapport_${ref.replaceAll(' ', '_')}.pdf',
                  ),
                ],
                subject: subject,
                text: '📧 Destinataire: $recipient\n\n$body',
              );
            }
          } else {
            throw e;
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
  }
  Future<void> _sendToClient() async {
    try {
      // Generate the document first
      await _generateWordFile();
      if (!mounted) return;

      final path = _lastGeneratedDocPath;
      if (path.isEmpty || !File(path).existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aucun document généré à envoyer.')),
        );
        return;
      }

      final ref = _nosReferences.text.trim();
      final clientEmail = _mailStand.text.trim();
      final recipientEmail = clientEmail.isNotEmpty ? clientEmail : 'typh94@live.fr';

      final subject = 'Rapport de vérification' + (ref.isNotEmpty ? ' - ' + ref : '');
      final body = 'Bonjour,\n\nVeuillez trouver ci-joint le rapport de vérification généré le ' +
          DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()) + '.\n\nCordialement';

      // Use Share to open share sheet with file attached
      final box = context.findRenderObject() as RenderBox?;
      final Offset topLeft = box != null ? box.localToGlobal(Offset.zero) : const Offset(0, 0);
      final Size size = box != null ? box.size : const Size(1, 1);
      final Rect origin = Rect.fromLTWH(topLeft.dx, topLeft.dy, size.width, size.height);

      await Share.shareXFiles(
        [
          XFile(
            path,
            mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            name: 'rapport_' + (ref.isNotEmpty ? ref.replaceAll(' ', '_') : 'VE') + '.docx',
          ),
        ],
        subject: subject,
        text: body + '\n\nDestinataire: ' + recipientEmail,
        sharePositionOrigin: origin,
      );

      if (!mounted) return;

      // Show instructions dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('📧 Instructions d\'envoi', style: TextStyle(color: blanc)),
          backgroundColor: blackAmont,
          content: Text(
            '1️⃣ Sélectionnez "Mail" dans le menu de partage\n\n'
                '2️⃣ Le fichier sera automatiquement joint\n\n'
                '3️⃣ Entrez l\'adresse email: $recipientEmail\n\n'
                '4️⃣ Vérifiez le contenu et appuyez sur Envoyer',
            style: TextStyle(color: blanc),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Compris', style: TextStyle(color: roseVE)),
            ),
          ],
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'envoi: $e')),
      );
    }
  }

  String _buildFicheTitle() {
    final s = _standName.text.trim();
    final h = _standHall.text.trim();
    final salon = _salonName.text.trim();
    final stand = _standNb.text.trim();
    if (s.isEmpty && h.isEmpty) return 'Rapport de Vérification Après Montage';
    if (salon.isNotEmpty && s.isNotEmpty && h.isNotEmpty && stand.isNotEmpty) return salon + ': ' + s + ' • Hall ' + h + ' ' + stand;
    if (s.isNotEmpty) return s;
    return 'Hall ' + h;
  }

  @override
  Widget build(BuildContext context) {

    return WillPopScope(
      onWillPop: () async {
        await _saveDraft();
        if (mounted) {
          Navigator.pop(context, true);
        }
        return false; // we handle the pop after saving
      },
      child: Scaffold(
       backgroundColor: fondRosePale,
     //   backgroundColor: Color(0xFF1A1A1A),
        appBar: AppBar(
          title: Text(
            _buildFicheTitle(),
            //  title: Text('Rapport de Vérification Après Montage - Page ${_currentPage + 1}/2',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: roseVE,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Sauvegarder',
              icon: Icon(Icons.save_outlined),
              onPressed: () async {
                await _saveDraft();
                if (mounted) {
                  Navigator.pop(context, true);
                }
              },
            ),
          ],
        ),
        body: PageView(

          controller: _pageController,
          physics: NeverScrollableScrollPhysics(),
          children: [
            _buildPage1(),
            _buildPage2(),
          ],
        ),
      ),
    );
  }


  Widget _buildPage1() {

    return Padding(
      padding: EdgeInsets.all(16),
      child: Form(

        key: _formKey1,
        child: SingleChildScrollView(
          child: Column(
            children: [

              SizedBox(height: 32),

              Text(
                'PHOTO GÉNÉRALE DE L\'ENSEMBLE DÉMONTABLE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),

              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: Icon(Icons.photo_library, color: roseVE),
                      label: Text('Galerie', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              if (_buildingPhotoPath.isNotEmpty) ...[
                SizedBox(height: 12),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: IoImage(
                    path: _buildingPhotoPath,
                    fit: BoxFit.cover,
                  ),
                ),
              ],

              SizedBox(height: 36),
              SizedBox(height: 32),
              Text(
                'INFORMATIONS GÉNÉRALES',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _techName,
                decoration: InputDecoration(
                  labelText: 'Nom du technicien',
                //  labelStyle: TextStyle(color: roseVE),
                  labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                    final Color color = states.contains(WidgetState.error)
                        ? Theme.of(context).colorScheme.error
                        : roseVE;
                    return TextStyle(color: color, letterSpacing: 1.3);
                  }),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                ),
                style: TextStyle(color: Colors.black), //  typed text white
                   validator: (value) => value!.isEmpty ? 'Entrez votre référence' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _localAdress,

                decoration: InputDecoration(
                  labelText: 'Adresse  du local',
                  labelStyle: TextStyle(color: fondRosePale),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                ),
                maxLines: 2,
                style: TextStyle(color: Colors.white),

              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _localTel,

                decoration: InputDecoration(
                  labelText: 'Téléphone  du local',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _localMail,

                decoration: InputDecoration(
                  labelText: 'Mail  du local',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _doName,

                decoration: InputDecoration(
                  labelText: 'Donneur d\'ordre',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),

                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white
              //  validator: (value) => value!.isEmpty ? 'Ce champ est requis' : null,

              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _objMission,

                decoration: InputDecoration(
                  labelText: 'Objet de la mission',
                 // labelStyle: TextStyle(color: roseVE),
                  labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                    final Color color = states.contains(WidgetState.error)
                        ? Theme.of(context).colorScheme.error
                        : roseVE;
                    return TextStyle(color: color, letterSpacing: 1.3);
                  }),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 3,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              TextFormField(
                controller: _dateTransmission,
                decoration: InputDecoration(
                  labelText: 'Date de transmission',
                 // labelStyle: TextStyle(color: Colors.white),
                  labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                    final Color color = states.contains(WidgetState.error)
                        ? Theme.of(context).colorScheme.error
                        : roseVE;
                    return TextStyle(color: color, letterSpacing: 1.3);
                  }),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  suffixIcon: Icon(Icons.calendar_today, color: bleuAmont),
                ),
                style: TextStyle(color: Colors.white),
                readOnly: true,
                onTap: () async {
                  DateTime selectedDate = DateTime.now();

                  await showCupertinoModalPopup(
                    context: context,
                    builder: (BuildContext context) {
                      return Container(
                        height: 300,
                        color: CupertinoColors.systemBackground,
                        child: Column(
                          children: [
                            // Header with Done button
                            Container(
                              height: 50,
                              color: CupertinoColors.systemGrey6,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  CupertinoButton(
                                    child: Text('Annuler', style: TextStyle(color: Colors.red)),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                  ),
                                  CupertinoButton(
                                    child: Text(
                                      'Valider',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: bleuAmont),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _dateTransmission.text = DateFormat('dd/MM/yyyy HH:mm').format(selectedDate);
                                      });
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            // Date picker
                            Expanded(
                              child: CupertinoDatePicker(
                                mode: CupertinoDatePickerMode.dateAndTime,
                                initialDateTime: DateTime.now(),
                                minimumYear: 2020,
                                maximumYear: 2030,
                                use24hFormat: true, // Format 24h
                                onDateTimeChanged: (DateTime newDate) {
                                  selectedDate = newDate;
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 32),

              SizedBox(height: 32),

              Text(
                'RENSEIGNEMENTS CONCERNANT L\'ÉVÈNEMENT',
                textAlign: TextAlign.center, // 👈 important ici
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _salonName,

                decoration: InputDecoration(
                  labelText: 'Nom Salon ',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 12),TextFormField(
                controller: _standName,

                decoration: InputDecoration(
                  labelText: 'Nom Stand ',
                  //labelStyle: TextStyle(color: Colors.white),
                  labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                    final Color color = states.contains(WidgetState.error)
                        ? Theme.of(context).colorScheme.error
                        : roseVE;
                    return TextStyle(color: color, letterSpacing: 1.3);
                  }),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _standHall,

                decoration: InputDecoration(
                  labelText: 'Hall',
                 // labelStyle: TextStyle(color: Colors.white),
                  labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                    final Color color = states.contains(WidgetState.error)
                        ? Theme.of(context).colorScheme.error
                        : roseVE;
                    return TextStyle(color: color, letterSpacing: 1.3);
                  }),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _standNb,

                decoration: InputDecoration(
                  labelText: 'Numéro ',
                 // labelStyle: TextStyle(color: Colors.white),
                  labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                    final Color color = states.contains(WidgetState.error)
                        ? Theme.of(context).colorScheme.error
                        : roseVE;
                    return TextStyle(color: color, letterSpacing: 1.3);
                  }),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _mailStand,

                decoration: InputDecoration(
                  labelText: 'Mail du client ',
                 // labelStyle: TextStyle(color: Colors.white),
                  labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                    final Color color = states.contains(WidgetState.error)
                        ? Theme.of(context).colorScheme.error
                        : roseVE;
                    return TextStyle(color: color, letterSpacing: 1.3);
                  }),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _siteName,

                decoration: InputDecoration(
                  labelText: 'Site ',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _siteAdress,

                decoration: InputDecoration(
                  labelText: 'Adresse ',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _standDscrptn,

                decoration: InputDecoration(
                  labelText: 'Description sommaire ',
                  //labelStyle: TextStyle(color: roseVE),
                  labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                    final Color color = states.contains(WidgetState.error)
                        ? Theme.of(context).colorScheme.error
                        : roseVE;
                    return TextStyle(color: color, letterSpacing: 1.3);
                  }),


                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _dateMontage,

                decoration: InputDecoration(
                  labelText: 'Date montage ',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _dateEvnmt,

                decoration: InputDecoration(
                  labelText: 'Date évènement ',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _catErpType,

                decoration: InputDecoration(
                  labelText: 'Catégorie et type ERP ',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _effectifMax,

                decoration: InputDecoration(
                  labelText: 'Effectif max du public admissible ',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 32),

              SizedBox(height: 32),
               Text(
                'RENSEIGNEMENTS CONCERNANT LES INTERVENANTS ',
                textAlign: TextAlign.center, // 👈 important ici
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: 12),
              TextFormField(
                controller: _orgaName,

                decoration: InputDecoration(
                  labelText: 'Organisateur ',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _installateurName,

                decoration: InputDecoration(
                  labelText: 'Installateur ',
                //  labelStyle: TextStyle(color: Colors.white),
                  labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                    final Color color = states.contains(WidgetState.error)
                        ? Theme.of(context).colorScheme.error
                        : roseVE;
                    return TextStyle(color: color, letterSpacing: 1.3);
                  }),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _exploitSiteName,

                decoration: InputDecoration(
                  labelText: 'Exploitant du site ',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _proprioMatosName,

                decoration: InputDecoration(
                  labelText: 'Propriétaire ',
                //  labelStyle: TextStyle(color: Colors.white),
                  labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                    final Color color = states.contains(WidgetState.error)
                        ? Theme.of(context).colorScheme.error
                        : roseVE;
                    return TextStyle(color: color, letterSpacing: 1.3);
                  }),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white
              ),

              SizedBox(height: 32),

              SizedBox(height: 32),

              Text(
                'RENSEIGNEMENTS CONCERNANT L\'ENSEMBLE DÉMONTABLE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _nbStructures,

                decoration: InputDecoration(
                  labelText: 'Nombre de structures totales',
                //  labelStyle: TextStyle(color: Colors.white),
                  labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                    final Color color = states.contains(WidgetState.error)
                        ? Theme.of(context).colorScheme.error
                        : roseVE;
                    return TextStyle(color: color, letterSpacing: 1.3);
                  }),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),

              SizedBox(height: 12),
              TextFormField(
                controller: _nbTableauxBesoin,

                decoration: InputDecoration(
                  labelText: 'Nombre de tableaux désirés',
                //  labelStyle: TextStyle(color: Colors.white),
                  labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                    final Color color = states.contains(WidgetState.error)
                        ? Theme.of(context).colorScheme.error
                        : roseVE;
                    return TextStyle(color: color, letterSpacing: 1.3);
                  }),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  nbTableaux = int.tryParse(_nbTableauxBesoin.text) ?? 0;
                  _ensureGrilControllersLength(nbTableaux);
                });
              },
              child: Text('Générer les grils '),
            ),

            SizedBox(height: 24),

// Generate question chunks
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: nbTableaux,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    Text(
                      'Gril Technique${index + 1}',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),

                    // Hauteur
                    TextFormField(
                      controller: _hauteurCtrls[index],
                      decoration: InputDecoration(
                        labelText: 'Hauteur',
                       // labelStyle: TextStyle(color: Colors.white),
                        labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                          final Color color = states.contains(WidgetState.error)
                              ? Theme.of(context).colorScheme.error
                              : roseVE;
                          return TextStyle(color: color, letterSpacing: 1.3);
                        }),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 12),

                    // Ouverture
                    TextFormField(
                      controller: _ouvertureCtrls[index],

                      decoration: InputDecoration(
                        labelText: 'Ouverture',
                       // labelStyle: TextStyle(color: Colors.white),
                        labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                          final Color color = states.contains(WidgetState.error)
                              ? Theme.of(context).colorScheme.error
                              : roseVE;
                          return TextStyle(color: color, letterSpacing: 1.3);
                        }),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 12),

                    // Profondeur
                    TextFormField(
                      controller: _profondeurCtrls[index],

                      decoration: InputDecoration(
                        labelText: 'Profondeur',
                       // labelStyle: TextStyle(color: Colors.white),
                        labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                          final Color color = states.contains(WidgetState.error)
                              ? Theme.of(context).colorScheme.error
                              : roseVE;
                          return TextStyle(color: color, letterSpacing: 1.3);
                        }),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 24),
                    // Ouverture
                    TextFormField(
                      controller: _nbTowerCtrls[index],

                      decoration: InputDecoration(
                        labelText: 'Si élevé sur pieds: nombre de towers',
                      //  labelStyle: TextStyle(color: Colors.white),
                        labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                          final Color color = states.contains(WidgetState.error)
                              ? Theme.of(context).colorScheme.error
                              : roseVE;
                          return TextStyle(color: color, letterSpacing: 1.3);
                        }),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 12), // Ouverture
                    TextFormField(
                      controller: _nbPalansCtrls[index],

                      decoration: InputDecoration(
                        labelText: 'Si suspendu: nombre de palans',
                      //  labelStyle: TextStyle(color: Colors.white),
                        labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                          final Color color = states.contains(WidgetState.error)
                              ? Theme.of(context).colorScheme.error
                              : roseVE;
                          return TextStyle(color: color, letterSpacing: 1.3);
                        }),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _marqueModelPPCtrls[index],

                      decoration: InputDecoration(
                        labelText: 'Marque et Modèle poutres et palans',
                      //  labelStyle: TextStyle(color: Colors.white),
                        labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                          final Color color = states.contains(WidgetState.error)
                              ? Theme.of(context).colorScheme.error
                              : roseVE;
                          return TextStyle(color: color, letterSpacing: 1.3);
                        }),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _rideauxEnseignesCtrls[index],

                      decoration: InputDecoration(
                        labelText: 'Rideaux',
                      //  labelStyle: TextStyle(color: Colors.white),
                        labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                          final Color color = states.contains(WidgetState.error)
                              ? Theme.of(context).colorScheme.error
                              : roseVE;
                          return TextStyle(color: color, letterSpacing: 1.3);
                        }),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _poidGrilTotalCtrls[index],

                      decoration: InputDecoration(
                        labelText: 'Poids total du gril équipé',
                      //  labelStyle: TextStyle(color: Colors.white),
                        labelStyle: WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
                          final Color color = states.contains(WidgetState.error)
                              ? Theme.of(context).colorScheme.error
                              : roseVE;
                          return TextStyle(color: color, letterSpacing: 1.3);
                        }),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 12),
                  ],
                );
              },
            ),
              SizedBox(height: 24),
              Text(
                'VITESSE DU VENT ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _windSpeed,

                decoration: InputDecoration(
                  labelText: 'La vitesse du vent en exploitation est limitée à ',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 1,
                style: TextStyle(color: Colors.white), //  typed text white

              ),
              SizedBox(height: 24),


              SizedBox(height: 30),
              Text(
                'DOCUMENTS CONSULTÉS ',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              SizedBox(height: 12),



              SizedBox(height: 12),
              buildQuestionTile('La notice technique du fabricant', 1),
              SizedBox(height: 16),
              buildQuestionTile('Les plans de détail coté de l\'ensemble démontable' , 2),
              SizedBox(height: 16),
              buildQuestionTile('Les notes de calculs' , 3),
              SizedBox(height: 16),
              buildQuestionTile('Les abaques de charges' , 4),
              SizedBox(height: 16),
              buildQuestionTile('L\'avis sur modèle' , 5),
              SizedBox(height: 16),
              buildQuestionTile('L\'avis sur dossier technique ' , 6),
              SizedBox(height: 16),
              buildQuestionTile('L\'étude de sol' , 7),
              SizedBox(height: 16),
              buildQuestionTile('Un avis solidité (antérieur à la parution de l\'arrêtè' , 8),
              SizedBox(height: 16),
              buildQuestionTile('La capacité portante de la charpente' , 9),
              SizedBox(height: 16),
              buildQuestionTile('Les PV de classement au feu des matériaux utilisés' , 10),
              SizedBox(height: 16),
              buildQuestionTile('L\'attestation de bon montage' , 11),
              SizedBox(height: 16),
              buildQuestionTile('Le dossier de sécurité de l\'évènement' , 12),
              SizedBox(height: 16),
              buildQuestionTile('VGP des palans' , 13),

              SizedBox(height: 64),

              Text(
                'TABLEAU DES VÉRIFICATIONS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 32),

              Text(
                'GÉNÉRALITÉS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: roseVE,
                ),
              ),
              SizedBox(height: 22),
              SizedBox(height: 34),

              buildVerifTile2('3. Principes Généraux', 3),
              SizedBox(height: 5),
              if (checkboxValues2[3] == 'NS') ...[
                Row(
                  children: [

                    Expanded(
                      child: TextFormField(
                        controller: _article3Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _pickArticlePhotoFromGallery(3),
                       icon: Icon(Icons.photo_library, color: roseVE),
                      label: Text('Galerie', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                    OutlinedButton.icon(
                       onPressed: () => _pickArticlePhoto(3),
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                if (_articlePhotos[3]?.imagePath != null && _articlePhotos[3]!.imagePath.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: roseVE, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.all(4),
                        child: IoImage(
                          path: _articlePhotos[3]!.imagePath,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              buildVerifTile2('5. Adéquation de la capacité d\'acceuil', 5),
              SizedBox(height: 5),
              if (checkboxValues2[5] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article5Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _pickArticlePhotoFromGallery(5),
                      icon: Icon(Icons.photo_library, color: roseVE),
                      label: Text('Galerie', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickArticlePhoto(5),
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                if (_articlePhotos[5]?.imagePath != null && _articlePhotos[5]!.imagePath.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                      decoration: BoxDecoration(
                      border: Border.all(color: roseVE, width: 1),
                      borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.all(4),
                  child: IoImage(
                  path: _articlePhotos[5]!.imagePath,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
                ),
                ),
                ),
                ],

                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              SizedBox(height: 25),

              Text(
                'IMPLANTATION',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: roseVE,
                ),
              ),
              SizedBox(height: 22),

              SizedBox(height: 34),

              buildVerifTile('6. Lieu d\'implantation : voisinages dangereux et risques d\'inflammation', 6),
              SizedBox(height: 5),
              if (checkboxValues2[6] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article6Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              buildVerifTile2('7. Adéquation avec le sol : État du sol, calage, plaque de répartition…', 7),
              SizedBox(height: 5),
              if (checkboxValues2[7] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article7Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _pickArticlePhoto(7),
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),




              SizedBox(height: 32),

              Text(
                'SOLIDITÉ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: roseVE,
                ),
              ),
              SizedBox(height: 22),

              SizedBox(height: 34),

              buildVerifTile2('9. Marquage : Marque, modèle, année…', 9),
              SizedBox(height: 5),
              if (checkboxValues2[9] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article9Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              buildVerifTile2('10. Respect des charges d\'exploitation et charges climatiques', 10),
              SizedBox(height: 5),
              if (checkboxValues2[10] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article10Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              buildVerifTile2('11. Adéquation, état et assemblages des ossatures', 11),
              SizedBox(height: 5),
              if (checkboxValues2[11] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article11Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              SizedBox(height: 32),

              Text(
                'AMÉNAGEMENTS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: roseVE,
                ),
              ),
              SizedBox(height: 22),

              SizedBox(height: 34),

              buildVerifTile2('12.	Planchers : État, jeu, décalage…', 12),
              SizedBox(height: 5),
              if (checkboxValues2[12] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article12Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              buildVerifTile2('13.	Contremarches : État, jeu, décalage…', 13),
              SizedBox(height: 5),
              if (checkboxValues2[13] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article13Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              buildVerifTile2('14.	Places assises pour les gradins : Nombre, implantation…', 14),
              SizedBox(height: 5),
              if (checkboxValues2[14] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article14Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              buildVerifTile2('15.	Places debout : Longueur et circulations', 15),
              SizedBox(height: 5),
              if (checkboxValues2[15] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article15Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              buildVerifTile2('16.	Dégagements : Nombre, qualité, répartition et balisage', 16),
              SizedBox(height: 5),
              if (checkboxValues2[16] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article16Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              buildVerifTile2('17.	Vomitoires et circulations : Configuration et projection', 17),
              SizedBox(height: 5),
              if (checkboxValues2[17] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article17Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              buildVerifTile2('18.	Dessous : Inaccessibilité au public, potentiel calorifique…', 18),
              SizedBox(height: 5),
              if (checkboxValues2[18] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article18Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              buildVerifTile2('19.	Escaliers et rampes accessibles au public : Qualité, état, assemblage…', 19),
              SizedBox(height: 5),
              if (checkboxValues2[19] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article19Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              buildVerifTile2('20.	Garde-corps : Qualité, état, assemblage…', 20),
              SizedBox(height: 5),
              if (checkboxValues2[20] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article20Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              buildVerifTile2('21.	Sièges et bancs fixes : Qualité, état, assemblage…', 21),
              SizedBox(height: 5),
              if (checkboxValues2[21] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article21Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              buildVerifTile2('22.	Sièges et banc non fixes : Nombre', 22),
              SizedBox(height: 5),
              if (checkboxValues2[22] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article22Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],

              SizedBox(height: 34),

              buildVerifTile2('23.	Sièges : Caractéristiques, PV de réaction au feu…', 23),
              SizedBox(height: 5),
              if (checkboxValues2[23] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article23Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              buildVerifTile('24.	Barrière anti-renversement : Présence, état, assemblage…', 24),
              SizedBox(height: 5),
              if (checkboxValues2[24] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article24Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),


              SizedBox(height: 32),
              Text(
                'EXPLOITATION',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: roseVE,
                ),
              ),
              SizedBox(height: 22),

              SizedBox(height: 34),

              buildVerifTile('25.	Impact sur le niveau de sécurité du lieu ', 25),
              SizedBox(height: 5),
              if (checkboxValues2[25] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article25Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),
              SizedBox(height: 34),

              buildVerifTile2('26.	Examen d\'adéquation, accroches, accessoires de levage, moyens de levage (type de palan, sécurisation, redondance, etc.), rapport de VGP', 26),
              SizedBox(height: 5),
              if (checkboxValues2[26] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article26Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),
              SizedBox(height: 34),

              buildVerifTile('27.	Habillages : PV de réaction au feu, état, assemblage…', 27),
              SizedBox(height: 5),
              if (checkboxValues2[27] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article27Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),
              SizedBox(height: 34),

              buildVerifTile2('28.	Cas des passerelles ne servant pas d\'espace d\'observation : bardage sur 2m de hauteur', 28),
              SizedBox(height: 5),
              if (checkboxValues2[28] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article28Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),
              SizedBox(height: 34),

              buildVerifTile('29.	Câbles électriques : absence d\'entrave à la circulation des personnes '
                  'Installations électriques : présence du plan avec localisation des dispositifs de coupure d\'urgence ', 29),
              SizedBox(height: 5),
              if (checkboxValues2[29] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article29Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),
              SizedBox(height: 34),

              buildVerifTile('30.	Présence du rapport de vérification des installations électriques ', 30),
              SizedBox(height: 5),
              if (checkboxValues2[30] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article30Obsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),
              SizedBox(height: 34),

              buildVerifTile('31.	Éclairage de sécurité en adéquation avec les conditions d\'exploitation ', 31),
              SizedBox(height: 5),
              if (checkboxValues2[31] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article31bsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),
              SizedBox(height: 34),

              buildVerifTile2('32	Anémomètre (plein air) : Présence, implantation et fonctionnement Modalités d\'évacuation ', 32),
              SizedBox(height: 5),
              if (checkboxValues2[32] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article32bsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),
              SizedBox(height: 34),

              buildVerifTile('33.	Diffusion de l\'alarme et de l\'alerte', 33),
              SizedBox(height: 5),
              if (checkboxValues2[33] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article33bsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),
              SizedBox(height: 34),

              buildVerifTile('34.	Moyens d\'extinction', 34),
              SizedBox(height: 5),
              if (checkboxValues2[34] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article34bsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),


              SizedBox(height: 32),
              Text(
                'CONTRÔLE, VERIFICATION ET INSPECTION',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: roseVE,
                ),
              ),
              SizedBox(height: 22),
              SizedBox(height: 34),

              buildVerifTile2('36.	Notices techniques : Présence', 36),
              SizedBox(height: 5),
              if (checkboxValues2[36] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article36bsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),
              SizedBox(height: 34),

              buildVerifTile2('37.	Conception : Présence d\'un avis sur modèle type ou sur dossier technique', 37),
              SizedBox(height: 5),
              if (checkboxValues2[37] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article37bsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),
              SizedBox(height: 34),

              buildVerifTile2('38.	Attestation de bon montage : Présence', 38),
              SizedBox(height: 5),
              if (checkboxValues2[38] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article38bsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 68),

              buildVerifTile2('39.	Dossier de sécurité : Présence et cohérence', 39),
              SizedBox(height: 5),
              if (checkboxValues2[39] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article39bsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),

              SizedBox(height: 32),
              Text(
                'IMPLANTATION PROLONGÉE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: roseVE,
                ),
              ),
              SizedBox(height: 22),
              SizedBox(height: 34),

              buildVerifTile2('45.	État de conservation', 45),
              SizedBox(height: 5),
              if (checkboxValues2[45] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article45bsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),
              SizedBox(height: 32),
              Text(
                'ENSEMBLE DÉMONTABLE EXISTANT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: roseVE,
                ),
              ),
              SizedBox(height: 22),
              SizedBox(height: 34),

              buildVerifTile2('47.	Solidité et stabilité : Présence de documents', 47),
              SizedBox(height: 5),
              if (checkboxValues2[47] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article47bsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),
              SizedBox(height: 34),

              buildVerifTile2('48.	Marquage', 48),
              SizedBox(height: 5),
              if (checkboxValues2[48] == 'NS') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _article48bsrvt,
                        decoration: InputDecoration(
                          labelText: 'observation',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(

                      onPressed: _pickFromCamera,
                      icon: Icon(Icons.camera_alt, color: roseVE),
                      label: Text('Prendre photo', style: TextStyle(color: roseVE)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: roseVE,
                        side: BorderSide(color: roseVE, width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              SizedBox(height: 34),
              SizedBox(height: 34),

              ElevatedButton(
                  onPressed: _goToNextPage,
                  child: Text('Suivant', style: TextStyle(color: bleuAmont)),
                  style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                      backgroundColor: Colors.white10)
              ),

              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
  Widget buildVerifTile2(String title, int index) {
    String? value = checkboxValues2[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Column(
              children: [
                Text('S', style: TextStyle(color: Colors.white)),
                Checkbox(
                  value: value == 'S',
                  onChanged: (bool? val) {
                    setState(() {
                      checkboxValues2[index] = 'S';
                    });
                  },
                ),
              ],
            ),
            SizedBox(width: 40),
            Column(
              children: [
                Text('NS', style: TextStyle(color: Colors.white)),
                Checkbox(
                  value: value == 'NS',
                  onChanged: (bool? val) {
                    setState(() {
                      checkboxValues2[index] = 'NS';
                    });
                  },
                ),
              ],
            ),
            SizedBox(width: 40),
            Column(
              children: [
                Text('SO', style: TextStyle(color: Colors.white)),
                Checkbox(
                  value: value == 'SO',
                  onChanged: (bool? val) {
                    setState(() {
                      checkboxValues2[index] = 'SO';
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        Divider(color: Colors.white30),
      ],
    );
  }
  Widget buildVerifTile(String title, int index) {
    String? value = checkboxValues2[index];
    TextEditingController controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Column(
              children: [
                Text('S', style: TextStyle(color: Colors.white)),
                Checkbox(
                  value: value == 'S',
                  onChanged: (bool? val) {
                    setState(() {
                      checkboxValues2[index] = 'S';
                    });
                  },
                ),
              ],
            ),
            SizedBox(width: 40),
            Column(
              children: [
                Text('NS', style: TextStyle(color: Colors.white)),
                Checkbox(
                  value: value == 'NS',
                  onChanged: (bool? val) {
                    setState(() {
                      checkboxValues2[index] = 'NS';
                    });
                  },
                ),
              ],
            ),
            SizedBox(width: 40),
            Column(
              children: [
                Text('SO', style: TextStyle(color: Colors.white)),
                Checkbox(
                  value: value == 'SO',
                  onChanged: (bool? val) {
                    setState(() {
                      checkboxValues2[index] = 'SO';
                    });
                  },
                ),
              ],
            ),
            SizedBox(width: 40),
            Column(
              children: [
                Text('HM', style: TextStyle(color: Colors.white)),
                Checkbox(
                  value: value == 'HM',
                  onChanged: (bool? val) {
                    setState(() {
                      checkboxValues2[index] = 'HM';
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        Divider(color: Colors.white30),
      ],
    );
  }
  Widget buildQuestionTile(String title, int index) {
    bool? value = checkboxValues[index];
    TextEditingController controller;

    switch (index) {
      case 1:
        controller = _question1;
        break;
      case 2:
        controller = _question2;
        break;
      case 3:
        controller = _question3;
        break;
      case 4:
        controller = _question4;
        break;
      case 5:
        controller = _question5;
        break;
      case 6:
        controller = _question6;
        break;
      case 7:
        controller = _question7;
        break;
      case 8:
        controller = _question8;
        break;
      case 9:
        controller = _question9;
        break;
      case 10:
        controller = _question10;
        break;
      case 11:
        controller = _question11;
        break;
      case 12:
        controller = _question12;
        break;
      case 13:
        controller = _question13;
        break;

      default:
        controller = TextEditingController();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Column(
              children: [
                Text('Oui', style: TextStyle(color: Colors.white)),
                Checkbox(
                  value: value == true,
                  activeColor: roseVE,
                  onChanged: (bool? val) {
                    setState(() {
                      checkboxValues[index] = val == true ? true : null;
                    });
                  },
                ),
              ],
            ),
            SizedBox(width: 40),
            Column(
              children: [
                Text('Non', style: TextStyle(color: Colors.white)),
                Checkbox(
                  value: value == false,
                  onChanged: (bool? val) {
                    setState(() {
                      checkboxValues[index] = val == true ? false : null;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        Divider(color: Colors.white30),
      ],
    );
  }

  Widget buildAvisTile(String title, int index) {
    bool? value = checkboxValues[index];
    TextEditingController controller;

    switch (index) {
      case 1:
        controller = _avisFav;
        break;
      case 2:
        controller = _avisDefav;
        break;
      default:
        controller = TextEditingController();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Column(
              children: [
                Text('Favorable', style: TextStyle(color: Colors.white)),
                Checkbox(
                  value: value == true,
                  activeColor: roseVE,
                  onChanged: (bool? val) {
                    setState(() {
                      checkboxValues[index] = val == true ? true : null;
                    });
                  },
                ),
              ],
            ),
            SizedBox(width: 40),
            Column(
              children: [
                Text('Défavorable', style: TextStyle(color: Colors.white)),
                Checkbox(
                  value: value == false,
                  onChanged: (bool? val) {
                    setState(() {
                      checkboxValues[index] = val == true ? false : null;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        Divider(color: Colors.white30),
      ],
    );
  }

  Widget _buildPage2() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey2,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 32),

              SizedBox(height: 24),

              Text(
                'AVIS FINAL',

                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white
                ),
              ),
              SizedBox(height: 12),

              SizedBox(height: 12),
              buildAvisTile('Votre avis est ... ', 1),



              SizedBox(height: 32),

              // Signature section
              Text(
                'SIGNATURE DU TECHNICIEN',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              SizedBox(height: 12),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: roseVE, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Signature(
                    controller: _signatureController,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      _signatureController.clear();
                      setState(() => _signaturePath = '');
                    },
                    icon: Icon(Icons.refresh, color: roseVE),
                    label: Text('Effacer', style: TextStyle(color: roseVE)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: roseVE,
                      side: BorderSide(color: roseVE, width: 2),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saveSignature,
                    icon: Icon(Icons.check, color: bleuAmont),
                    label: Text('Enregistrer la signature', style: TextStyle(color: bleuAmont)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                  ),
                ],
              ),
              if ((_signatureBytes != null && _signatureBytes!.isNotEmpty) || _signaturePath.isNotEmpty) ...[
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: roseVE, width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _signatureBytes != null && _signatureBytes!.isNotEmpty
                        ? Image.memory(
                            _signatureBytes!,
                            width: 120,
                            height: 60,
                            fit: BoxFit.contain,
                          )
                        : IoImage(
                            path: _signaturePath,
                            width: 120,
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ],

              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _goToPreviousPage,
                    child: Text('Précédent', style: TextStyle(color: bleuAmont)),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                      backgroundColor: Colors.white10,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _saveDraft,
                    child: Text('Save', style: TextStyle(color: bleuAmont)),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                      backgroundColor: Colors.white10,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _generateWordFile(preview: true),
                    child: Text('Aperçu', style: TextStyle(color: bleuAmont)),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                      backgroundColor: Colors.white10,
                    ),
                  ),
                 
                ],
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _showPdfPreview,
                    child: Text('Aperçu PDF', style: TextStyle(color: bleuAmont)),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                      backgroundColor: Colors.white10,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _generateWordFile,
                    child: Text('Générer', style: TextStyle(color: bleuAmont)),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                      backgroundColor: Colors.white10,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  ElevatedButton.icon(
                    onPressed: () async {
                      // Utiliser l'email du destinataire depuis votre formulaire
                      //   await _sendEmailWithAttachment(_mailStand.text.trim(), _localMail.text.trim(), _salonName.text.trim(), _standName.text.trim(), _standHall.text.trim(), _standNb.text.trim());
                         await _sendEmailWithAttachment(preview: false);
                    },
                    icon: Icon(Icons.email),
                    label: Text('Envoyer par Email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bleuAmont,
                      foregroundColor: blanc,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // First generate the Word document
                      await _generateWordFile(preview: false);

                      if (_lastGeneratedDocPath.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Veuillez d\'abord générer le document Word')),
                        );
                        return;
                      }

                      try {
                        // Show loading dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => Center(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text('Conversion en PDF...'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );

                        // Simple approach: Share the DOCX and suggest PDF conversion
                        Navigator.pop(context); // Close loading dialog

                        final result = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Exporter en PDF'),
                            content: Text(
                                'Voulez-vous:\n\n'
                                    '1. Partager le document Word (vous pourrez le convertir en PDF sur votre appareil)\n'
                                    '2. Ouvrir le document (puis "Imprimer" → "Enregistrer en PDF")'
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, 'cancel'),
                                child: Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, 'share'),
                                child: Text('Partager'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, 'open'),
                                child: Text('Ouvrir'),
                              ),
                            ],
                          ),
                        );

                        if (result == 'share') {
                          await Share.shareXFiles(
                            [XFile(_lastGeneratedDocPath)],
                            subject: 'Rapport de Vérification - ${_nosReferences.text}',
                            text: 'Rapport de Vérification',
                          );
                        } else if (result == 'open') {
                          await OpenFilex.open(_lastGeneratedDocPath);
                        }
                      } catch (e) {
                        Navigator.pop(context); // Close loading dialog if still open
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Exporter en PDF"),
                  ),
                ],

              ),
              SizedBox(height: 32),

            ],
          ),
        ),
      ),
    );
  }
}




