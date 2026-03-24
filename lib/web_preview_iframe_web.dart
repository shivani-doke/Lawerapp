import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

final Set<String> _registeredViewTypes = <String>{};

void registerPreviewIframe(String viewType, String url) {
  if (_registeredViewTypes.contains(viewType)) {
    return;
  }

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    return html.IFrameElement()
      ..src = url
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
  });

  _registeredViewTypes.add(viewType);
}

Widget buildPreviewIframe(String viewType) {
  return HtmlElementView(viewType: viewType);
}
