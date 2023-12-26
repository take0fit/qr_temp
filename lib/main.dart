import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

void main() {
  // GetMaterialAppはGetXライブラリで提供されているウィジェットで、アプリの最上位に配置します。これにより、GetXの全ての機能（状態管理、依存性管理、ルート管理など）がアプリ全体で利用可能になります
  runApp(const GetMaterialApp(home: QRCodeReader()));
}

// QRCodeReaderは状態を持たないウィジェット（StatelessWidget）で、アプリバーとボディ（QRViewWidget）、および再スキャンを行うためのフローティングアクションボタンが含まれる
class QRCodeReader extends StatelessWidget {
  const QRCodeReader({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Code Reader with GetX')),
      body: const QRViewWidget(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.offAndToNamed('/'),
        tooltip: 'Scan Again',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

// QRViewWidgetは状態を持つウィジェット（StatefulWidget）で、QRコードスキャナのビューと結果を表示する部分を持つ
class QRViewWidget extends StatefulWidget {
  const QRViewWidget({super.key});

  @override
  QRViewWidgetState createState() => QRViewWidgetState(); // createState()がパブリックなメソッドのためQRViewWidgetStateもパブリックなクラスとして使用する
}

class QRViewWidgetState extends State<QRViewWidget> {
  Barcode? result;
  QRViewController? controller;
  // GlobalKeyはFlutterのウィジェットツリー全体で一意であるため、それを使用して任意の場所から特定のウィジェットやその状態にアクセスすることができます。
  // qrKeyは後でQRViewウィジェットを作成する際に使用され、そのウィジェットに対する一意の参照を提供しアプリケーションのどこからでもQRViewウィジェットにアクセスすることを可能とさせるため使用
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  // reassembleはFlutterのStateオブジェクトに定義されているメソッドで、主にホットリロード時に呼び出される
  // ホットリロード時でもカメラの状態が保持され、うまく動作し続けることを保証する（開発中に役立つ処理）
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      // Android（AndroidのカメラAPIの特性や、QRコードスキャナーの動作特性上必要）の場合はカメラを一時停止(pauseCamera())し、その後、カメラを再開(resumeCamera())する。
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  // buildメソッド内でQRコードのスキャン結果を表示する部分を定義
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(flex: 4, child: _buildQrView(context)),
        Expanded(
          flex: 1,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // スキャンが完了した場合、スキャンしたバーコードの種類とデータをテキストとして表示
                if (result != null)
                  Text('Barcode Type: ${describeEnum(result!.format)}   Data: ${result!.code}')
                else
                  const Text('Scan a code'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // スキャナのビュー部分は_buildQrViewメソッドで構築
  Widget _buildQrView(BuildContext context) {
    // QRコードのスキャンエリアのサイズをデバイスのスクリーンサイズに基づいて動的に決定
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
        MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;
    // QRコードをスキャンするためのカメラビューを提供するQRView（qr_code_scanner パッケージから提供されるWidget）を作成
    return QRView(
      // keyが必須である理由は、ライブラリの実装によりますが、おそらくQRView内部で状態管理やウィジェットの一意性の確保を行うためにkeyが必要となるからでしょう。このkeyにより、QRViewの内部でウィジェットの状態を追跡し、特定のインスタンスを一意に識別することが可能となります。
      // QRコードのスキャン処理が複数の画面や場所で行われる可能性があるため、それぞれのQRViewが持つ状態（例えば、カメラの起動状態やスキャンデータ）を正しく管理するためには、各QRViewインスタンスを一意に識別できる必要がある
      key: qrKey,
      // QRコードがスキャンされたときに何をするかを定義
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
          borderColor: Colors.red,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: scanArea),
    );
  }

  // _onQRViewCreatedメソッドでスキャナの初期設定と、QRコードがスキャンされた際のアクションを定義
  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    // QRコードがスキャンされたデータを監視し、新しいデータがストリームに来たときにそのデータを処理するリスナー
    // scannedDataStreamは、QRコードがスキャンされるたびに新しいデータを発行するストリーム
    // スキャンされたデータは scannedDataStream をリッスンすることで取得
    controller.scannedDataStream.listen((scanData) {
      // controller.pauseCamera(); : これにより、カメラの動作が一時停止。これは、QRコードの読み取りが成功した後にダイアログを表示するため、その間にカメラが動作し続けることを防ぐ
      controller.pauseCamera();
      // setStateメソッドはFlutterのStateクラスに用意されており、呼び出されると第一引数のVoidCallbackが実行された後buildメソッドが再度実行されてUIが更新される
      setState(() {
        // スキャンしたデータをresultフィールドに保存
        result = scanData;
      });
      // スキャンデータを取得した後はダイアログを表示してスキャン結果をユーザーに通知
      // Get.dialog()は、GetXライブラリのメソッドで、新たなダイアログを現在のスクリーン上に表示します。このメソッドの引数には、表示するウィジェット（この場合はAlertDialog）を指定
      Get.dialog(
        AlertDialog(
          title: const Text('QR Code Result'),
          content: Text(scanData.code ?? 'デフォルトの文字列'),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
                controller.resumeCamera();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  // Widgetが廃棄されるときにカメラのリソースを開放するためのdisposeメソッドを定義
  // Flutterのライフサイクルメソッドであるdisposeをオーバーライド
  // ウィジェットがウィジェットツリーから完全に削除されるとき（たとえば画面遷移で次の画面に移るときなど）にフレームワークから呼び出されます。このメソッドは通常、ウィジェットが作成したリソースをクリーンアップするために使用さru
  @override
  void dispose() {
    // QRViewController（QRコードのスキャンに使用したカメラのリソースを管理するオブジェクト）の dispose メソッドを呼び出す
    // カメラリソースを適切に開放し、カメラリソースのリークを防ぎ、アプリのパフォーマンスを維持する
    controller?.dispose();
    // ウィジェットの基底クラスであるclass StatefulWidgetの親classのdisposeメソッドを呼び出す
    // Stateクラスが必要とするクリーンアップ処理が実行される
    super.dispose();
  }
}
