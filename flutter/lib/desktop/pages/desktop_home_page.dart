import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/animated_rotation_widget.dart';
import 'package:flutter_hbb/common/widgets/custom_password.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/plugin/ui_manager.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart' as window_size;

import '../widgets/button.dart';

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({Key? key}) : super(key: key);

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

const borderColor = Color(0xFF2F65BA);

class _DesktopHomePageState extends State<DesktopHomePage>
    with AutomaticKeepAliveClientMixin {
  final _leftPaneScrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;
  var systemError = '';
  StreamSubscription? _uniLinksSubscription;
  var svcStopped = false.obs;
  var watchIsCanScreenRecording = false;
  var watchIsProcessTrust = false;
  var watchIsInputMonitoring = false;
  var watchIsCanRecordAudio = false;
  Timer? _updateTimer;
  bool isCardClosed = false;

  final RxBool _editHover = false.obs;

  final GlobalKey _childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isIncomingOnly = bind.isIncomingOnly();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLeftPane(context),
        if (!isIncomingOnly) const VerticalDivider(width: 1),
        if (!isIncomingOnly) Expanded(child: buildRightPane(context)),
      ],
    );
  }

  Widget buildLeftPane(BuildContext context) {
    final isIncomingOnly = bind.isIncomingOnly();
    final isOutgoingOnly = bind.isOutgoingOnly();
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Container(
        width: isIncomingOnly ? 280.0 : 200.0,
        color: Theme.of(context).colorScheme.background,
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _leftPaneScrollController,
              child: Column(
                key: _childKey,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      "Topdebug",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: buildPopupMenu(context),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 6,
              left: 12,
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  child: Obx(
                    () => Icon(
                      Icons.settings,
                      color: _editHover.value
                          ? textColor
                          : Colors.grey.withOpacity(0.5),
                      size: 22,
                    ),
                  ),
                  onTap: () => {
                    if (DesktopSettingPage.tabKeys.isNotEmpty)
                      {
                        DesktopSettingPage.switch2page(
                            DesktopSettingPage.tabKeys[0])
                      }
                  },
                  onHover: (value) => _editHover.value = value,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget buildRightPane(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ConnectionPage(),
    );
  }

  Widget buildPopupMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings),
              SizedBox(width: 8),
              Text('Settings'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'settings') {
          if (DesktopSettingPage.tabKeys.isNotEmpty) {
            DesktopSettingPage.switch2page(DesktopSettingPage.tabKeys[0]);
          }
        }
      },
    );
  }
}