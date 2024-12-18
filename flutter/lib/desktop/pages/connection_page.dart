import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/peer_tab_page.dart';
import 'package:get/get.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({Key? key}) : super(key: key);

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: PeerTabPage(),
              ),
            ],
          ).paddingOnly(left: 12.0),
        ),
      ],
    );
  }
}