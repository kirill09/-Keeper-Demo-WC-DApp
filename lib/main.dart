import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  static const projectId = ''; // TODO your WC projectId
  static const callback = 'demomyapplication:';
  static const namespace = 'waves';
  static const testChainId = 'waves:T';
  static const mainChainId = 'waves:W';
  static const invoke = {
    "type": 16,
    "dApp": "3N3Cn2pYtqzj7N9pviSesNe8KG9Cmb718Y1",
    "call": {
      "function": "foo",
      "args": [
        {"type": "binary", "value": "base64:AQa3b8tH"},
        {
          "type": "list",
          "value": [
            {"type": "string", "value": "aaa"},
            {"type": "string", "value": "bbb"}
          ]
        }
      ]
    }
  };
  static const currentChainId = testChainId;

  Web3App? _wcClient;
  String? _topic;
  final _log = <String>[];

  @override
  void initState() {
    super.initState();

    _init();
  }

  Future<void> _init() async {
    _wcClient = await Web3App.createInstance(
      relayUrl: 'wss://relay.walletconnect.com',
      projectId: projectId,
      metadata: const PairingMetadata(
        name: 'Keeper Demo DApp',
        description: 'DApp Description',
        url: 'https://keeper-wallet.app/',
        icons: ['https://avatars.githubusercontent.com/u/18295288?s=200&v=4'],
      ),
    );
    _wcClient?.onSessionPing.subscribe((SessionPing? ping) {
      _logadd('onSessionPing: $ping');
    });
    _wcClient?.onSessionEvent.subscribe((SessionEvent? session) {
      _logadd('onSessionEvent: $session');
    });
    _wcClient?.onSessionConnect.subscribe((SessionConnect? connect) {
      _logadd('onSessionConnect: $connect');
      _setTopic(connect?.session.topic);
    });
    _wcClient?.onSessionUpdate.subscribe((SessionUpdate? update) {
      _logadd('onSessionUpdate: $update');
    });
    _wcClient?.onSessionExpire.subscribe((SessionExpire? expire) {
      _logadd('onSessionExpire: $expire');
      _setTopic(null);
    });
    _wcClient?.onSessionDelete.subscribe((SessionDelete? delete) {
      _logadd('onSessionDelete: $delete');
      _setTopic(null);
    });

    final activeSessions = _wcClient?.getActiveSessions() ?? {};

    if (activeSessions.keys.isNotEmpty) {
      _setTopic(activeSessions.keys.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Keeper Demo DApp')),
        body: SafeArea(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _topic == null ? _onPairing : null,
                child: const Text('Pairing'),
              ),
              ElevatedButton(
                onPressed: _topic == null ? null : _onDisconnect,
                child: const Text('Disconnect'),
              ),
              ElevatedButton(
                onPressed: _topic == null ? null : _onSign,
                child: const Text('Sign INVOKE SCRIPT'),
              ),
              Text('topic: ${_topic ?? ''}'),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(_log.reversed.join('\n\n')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setTopic(String? topic) {
    setState(() {
      _topic = topic;
    });
  }

  void _logadd(String message) {
    setState(() {
      _log.add(message);
    });
  }

  void _onPairing() async {
    _onDisconnect();
    final resp = await _wcClient?.connect(requiredNamespaces: {
      namespace: const RequiredNamespace(
        chains: [currentChainId],
        methods: [
          'waves_signTransaction',
          'waves_signTransactionPackage',
          'waves_signMessage',
          'waves_signTypedData',
        ],
        events: [],
      ),
    });

    final wcUrl = resp?.uri.toString();
    openKeeper('auth', wcUrl: wcUrl);
  }

  Future<void> _onDisconnect() async {
    final topic = _topic;
    if (topic == null) return;

    await _wcClient?.disconnectSession(
      topic: topic,
      reason: Errors.getSdkError(Errors.USER_DISCONNECTED),
    );

    _setTopic(null);
  }

  Future<void> _onSign() async {
    final topic = _topic;
    if (topic == null) return;

    _wcClient
        ?.request(
          topic: topic,
          chainId: currentChainId,
          request: SessionRequestParams(
            method: 'waves_signTransaction',
            params: [invoke],
          ),
        )
        .then((value) => _logadd('request result: $value'))
        .onError((error, _) => _logadd('request error: $error'));

    openKeeper('wakeup', topic: topic);
  }

  // open the keeper
  // [method] accepting 'auth' and 'wakeup'
  // [wcUrl] required for authorization WalletConnect paring url
  // [topic] required for signatures session topic
  Future<void> openKeeper(String method, {String? wcUrl, String? topic}) async {
    _logadd('openKeeper method: $method, wcUrl: $wcUrl, topic: $topic');

    final parameters = <String>[];
    if (wcUrl != null) {
      parameters.add('wcurl=${Uri.encodeComponent(wcUrl)}');
    }
    if (topic != null) {
      parameters.add('topic=$topic');
    }

    parameters.add('callback=$callback');

    final query = parameters.join('&');
    final url = Uri.parse('https://link.keeper-wallet.app/$method?$query');

    launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
