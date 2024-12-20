// main window right pane

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/connection_page_title.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_hbb/models/peer_model.dart';

import '../../common.dart';
import '../../common/formatter/id_formatter.dart';
import '../../common/widgets/peer_tab_page.dart';
import '../../common/widgets/autocomplete.dart';
import '../../models/platform_model.dart';
import '../widgets/button.dart';

class OnlineStatusWidget extends StatefulWidget {
  const OnlineStatusWidget({Key? key, this.onSvcStatusChanged})
      : super(key: key);

  final VoidCallback? onSvcStatusChanged;

  @override
  State<OnlineStatusWidget> createState() => _OnlineStatusWidgetState();
}

/// State for the connection page.
class _OnlineStatusWidgetState extends State<OnlineStatusWidget> {
  final _svcStopped = Get.find<RxBool>(tag: 'stop-service');
  final _svcIsUsingPublicServer = true.obs;
  Timer? _updateTimer;

  double get em => 14.0;
  double? get height => bind.isIncomingOnly() ? null : em * 3;

  void onUsePublicServerGuide() {
    const url = "https://rustdesk.com/pricing.html";
    canLaunchUrlString(url).then((can) {
      if (can) {
        launchUrlString(url);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _updateTimer = periodic_immediate(Duration(seconds: 1), () async {
      updateStatus();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Widget basicWidget() {
    return Row(
      children: [
        Obx(() => _buildConnStatusMsg()),
        Obx(() {
          if (_svcIsUsingPublicServer.value) {
            return Row(
              children: [
                Text(
                  ' - ' + translate('public_relay_tip'),
                  style: TextStyle(fontSize: em),
                ),
                TextButton(
                  onPressed: onUsePublicServerGuide,
                  child: Text(
                    translate('learn_more'),
                    style: TextStyle(fontSize: em),
                  ),
                ),
              ],
            );
          } else {
            return Container();
          }
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncomingOnly = bind.isIncomingOnly();
    return Container(
      height: height,
      child: basicWidget(),
    ).paddingOnly(right: isIncomingOnly ? 8 : 0);
  }

  _buildConnStatusMsg() {
    widget.onSvcStatusChanged?.call();
    return Text(
      _svcStopped.value
          ? translate("Service is not running")
          : stateGlobal.svcStatus.value == SvcStatus.connecting
              ? translate("connecting_status")
              : stateGlobal.svcStatus.value == SvcStatus.notReady
                  ? translate("not_ready_status")
                  : translate('Ready'),
      style: TextStyle(fontSize: em),
    );
  }

  updateStatus() async {
    final status =
        jsonDecode(await bind.mainGetConnectStatus()) as Map<String, dynamic>;
    final statusNum = status['status_num'] as int;
    if (statusNum == 0) {
      stateGlobal.svcStatus.value = SvcStatus.connecting;
    } else if (statusNum == -1) {
      stateGlobal.svcStatus.value = SvcStatus.notReady;
    } else if (statusNum == 1) {
      stateGlobal.svcStatus.value = SvcStatus.ready;
    } else {
      stateGlobal.svcStatus.value = SvcStatus.notReady;
    }
    _svcIsUsingPublicServer.value = await bind.mainIsUsingPublicServer();
  }
}

/// Connection page for connecting to a remote peer.
class ConnectionPage extends StatefulWidget {
  const ConnectionPage({Key? key}) : super(key: key);

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

/// State for the connection page.
class _ConnectionPageState extends State<ConnectionPage>
    with SingleTickerProviderStateMixin, WindowListener {
  /// Controller for the id input bar.
  final _idController = IDTextEditingController();

  final RxBool _idInputFocused = false.obs;

  bool isWindowMinimized = false;
  List<Peer> peers = [];

  bool isPeersLoading = false;
  bool isPeersLoaded = false;
  // https://github.com/flutter/flutter/issues/157244
  Iterable<Peer> _autocompleteOpts = [];

  @override
  void initState() {
    super.initState();
    if (_idController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final lastRemoteId = await bind.mainGetLastRemoteId();
        if (lastRemoteId != _idController.id) {
          setState(() {
            _idController.id = lastRemoteId;
          });
        }
      });
    }
    Get.put<IDTextEditingController>(_idController);
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    _idController.dispose();
    windowManager.removeListener(this);
    if (Get.isRegistered<IDTextEditingController>()) {
      Get.delete<IDTextEditingController>();
    }
    if (Get.isRegistered<TextEditingController>()) {
      Get.delete<TextEditingController>();
    }
    super.dispose();
  }

  @override
  void onWindowEvent(String eventName) {
    super.onWindowEvent(eventName);
    if (eventName == 'minimize') {
      isWindowMinimized = true;
    } else if (eventName == 'maximize' || eventName == 'restore') {
      if (isWindowMinimized && isWindows) {
        // windows can't update when minimized.
        Get.forceAppUpdate();
      }
      isWindowMinimized = false;
    }
  }

  @override
  void onWindowEnterFullScreen() {
    // Remove edge border by setting the value to zero.
    stateGlobal.resizeEdgeSize.value = 0;
  }

  @override
  void onWindowLeaveFullScreen() {
    // Restore edge border to default edge size.
    stateGlobal.resizeEdgeSize.value = stateGlobal.isMaximized.isTrue
        ? kMaximizeEdgeSize
        : windowResizeEdgeSize;
  }

  @override
  void onWindowClose() {
    super.onWindowClose();
    bind.mainOnMainWindowClose();
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoingOnly = bind.isOutgoingOnly();
    return Row(  // 使用Row来创建左右布局
      children: [
        // 左侧软件说明区域
        Container(
          width: 250,  // 设置合适的宽度
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 添加 logo 图片
              Container(
                width: 150,  // logo 宽度
                height: 50,  // logo 高度
                margin: EdgeInsets.only(bottom: 20),
                child: Image.asset(
                  'assets/logo.png',  // 修改为正确的路径
                  fit: BoxFit.contain,
                ),
              ),
              Text(
                'TopDebug远程调试软件',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                '软件功能介绍：',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1. 远程控制：安全快速的远程桌面访问'),
                      SizedBox(height: 8),
                      Text('2. 文件传输：便捷的跨设备文件传输'),
                      SizedBox(height: 8),
                      Text('3. 安全加密：端到端加密确保数据安全'),
                    ],
                  ),
                ),
              ),
              // 底部设置按钮
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(top: 16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    // 处理设置按钮点击事件
                    bind.mainShowSettingDialog();
                  },
                  icon: Icon(Icons.settings, color: Colors.grey[700]),
                  label: Text(
                    '设置',
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 右侧主要内容区域
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    // 隐藏原有的输入框和分隔符
                    Offstage(
                      offstage: true,
                      child: Row(
                        children: [
                          Flexible(child: _buildRemoteIDTextField(context)),
                        ],
                      ).marginOnly(top: 22),
                    ),
                    Offstage(
                      offstage: true,
                      child: Column(
                        children: [
                          SizedBox(height: 12),
                          Divider().paddingOnly(right: 12),
                        ],
                      ),
                    ),
                    Expanded(child: PeerTabPage()),
                  ],
                ).paddingOnly(left: 12.0),
              ),
              if (!isOutgoingOnly) const Divider(height: 1),
              if (!isOutgoingOnly) OnlineStatusWidget()
            ],
          ),
        ),
      ],
    );
  }

  /// Callback for the connect button.
  /// Connects to the selected peer.
  void onConnect({bool isFileTransfer = false}) {
    var id = _idController.id;
    connect(context, id, isFileTransfer: isFileTransfer);
  }

  Future<void> _fetchPeers() async {
    setState(() {
      isPeersLoading = true;
    });
    await Future.delayed(Duration(milliseconds: 100));
    peers = await getAllPeers();
    setState(() {
      isPeersLoading = false;
      isPeersLoaded = true;
    });
  }

  /// UI for the remote ID TextField.
  /// Search for a peer.
  Widget _buildRemoteIDTextField(BuildContext context) {
    var w = Container(
      width: 320 + 20 * 2,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(13)),
          border: Border.all(color: Theme.of(context).colorScheme.background)),
      child: Ink(
        child: Column(
          children: [
            getConnectionPageTitle(context, false).marginOnly(bottom: 15),
            Row(
              children: [
                Expanded(
                    child: Autocomplete<Peer>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      _autocompleteOpts = const Iterable<Peer>.empty();
                    } else if (peers.isEmpty && !isPeersLoaded) {
                      Peer emptyPeer = Peer(
                        id: '',
                        username: '',
                        hostname: '',
                        alias: '',
                        platform: '',
                        tags: [],
                        hash: '',
                        password: '',
                        forceAlwaysRelay: false,
                        rdpPort: '',
                        rdpUsername: '',
                        loginName: '',
                      );
                      _autocompleteOpts = [emptyPeer];
                    } else {
                      String textWithoutSpaces =
                          textEditingValue.text.replaceAll(" ", "");
                      if (int.tryParse(textWithoutSpaces) != null) {
                        textEditingValue = TextEditingValue(
                          text: textWithoutSpaces,
                          selection: textEditingValue.selection,
                        );
                      }
                      String textToFind = textEditingValue.text.toLowerCase();
                      _autocompleteOpts = peers
                          .where((peer) =>
                              peer.id.toLowerCase().contains(textToFind) ||
                              peer.username
                                  .toLowerCase()
                                  .contains(textToFind) ||
                              peer.hostname
                                  .toLowerCase()
                                  .contains(textToFind) ||
                              peer.alias.toLowerCase().contains(textToFind))
                          .toList();
                    }
                    return _autocompleteOpts;
                  },
                  fieldViewBuilder: (
                    BuildContext context,
                    TextEditingController fieldTextEditingController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted,
                  ) {
                    fieldTextEditingController.text = _idController.text;
                    Get.put<TextEditingController>(fieldTextEditingController);
                    fieldFocusNode.addListener(() async {
                      _idInputFocused.value = fieldFocusNode.hasFocus;
                      if (fieldFocusNode.hasFocus && !isPeersLoading) {
                        _fetchPeers();
                      }
                    });
                    final textLength =
                        fieldTextEditingController.value.text.length;
                    // select all to facilitate removing text, just following the behavior of address input of chrome
                    fieldTextEditingController.selection =
                        TextSelection(baseOffset: 0, extentOffset: textLength);
                    return Obx(() => TextField(
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: TextInputType.visiblePassword,
                          focusNode: fieldFocusNode,
                          style: const TextStyle(
                            fontFamily: 'WorkSans',
                            fontSize: 22,
                            height: 1.4,
                          ),
                          maxLines: 1,
                          cursorColor:
                              Theme.of(context).textTheme.titleLarge?.color,
                          decoration: InputDecoration(
                              filled: false,
                              counterText: '',
                              hintText: _idInputFocused.value
                                  ? null
                                  : translate('Enter Remote ID'),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 13)),
                          controller: fieldTextEditingController,
                          inputFormatters: [IDTextInputFormatter()],
                          onChanged: (v) {
                            _idController.id = v;
                          },
                          onSubmitted: (_) {
                            onConnect();
                          },
                        ));
                  },
                  onSelected: (option) {
                    setState(() {
                      _idController.id = option.id;
                      FocusScope.of(context).unfocus();
                    });
                  },
                  optionsViewBuilder: (BuildContext context,
                      AutocompleteOnSelected<Peer> onSelected,
                      Iterable<Peer> options) {
                    options = _autocompleteOpts;
                    double maxHeight = options.length * 50;
                    if (options.length == 1) {
                      maxHeight = 52;
                    } else if (options.length == 3) {
                      maxHeight = 146;
                    } else if (options.length == 4) {
                      maxHeight = 193;
                    }
                    maxHeight = maxHeight.clamp(0, 200);

                    return Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Material(
                            elevation: 4,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: maxHeight,
                                maxWidth: 319,
                              ),
                              child: peers.isEmpty && isPeersLoading
                                  ? Container(
                                      height: 80,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: ListView(
                                        children: options
                                            .map((peer) =>
                                                AutocompletePeerTile(
                                                  onSelect: () =>
                                                      onSelected(peer),
                                                  peer: peer,
                                                ))
                                            .toList(),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      child: w,
    );
  }
}
