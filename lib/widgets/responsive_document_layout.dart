import 'dart:math' as math;

import 'package:flutter/material.dart';

class ResponsiveDocumentLayout extends StatefulWidget {
  const ResponsiveDocumentLayout({
    super.key,
    required this.leftPanel,
    required this.rightPanel,
    this.backgroundColor = const Color(0xfff5f6f8),
    this.mobileBreakpoint = 1100,
    this.desktopGap = 30,
    this.mobileGap = 20,
    this.desktopPadding = const EdgeInsets.all(30),
    this.mobilePadding = const EdgeInsets.all(16),
    this.mobilePreviewHeight = 520,
    this.leftFlex = 2,
    this.rightFlex = 2,
  });

  final Widget leftPanel;
  final Widget rightPanel;
  final Color backgroundColor;
  final double mobileBreakpoint;
  final double desktopGap;
  final double mobileGap;
  final EdgeInsets desktopPadding;
  final EdgeInsets mobilePadding;
  final double mobilePreviewHeight;
  final int leftFlex;
  final int rightFlex;

  @override
  State<ResponsiveDocumentLayout> createState() =>
      _ResponsiveDocumentLayoutState();
}

class _ResponsiveDocumentLayoutState extends State<ResponsiveDocumentLayout> {
  final ScrollController _mobileScrollController = ScrollController();
  final ScrollController _desktopLeftScrollController = ScrollController();

  @override
  void dispose() {
    _mobileScrollController.dispose();
    _desktopLeftScrollController.dispose();
    super.dispose();
  }

  Widget _buildScrollbar({
    required ScrollController controller,
    required Widget child,
  }) {
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      thickness: 12,
      radius: const Radius.circular(999),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < widget.mobileBreakpoint;
        final mediaQuery = MediaQuery.of(context);
        final viewportHeight = mediaQuery.size.height -
            mediaQuery.padding.top -
            mediaQuery.padding.bottom;
        final resolvedMobilePreviewHeight = math.max(
          widget.mobilePreviewHeight,
          viewportHeight * 0.78,
        );

        return Container(
          color: widget.backgroundColor,
          padding: isCompact ? widget.mobilePadding : widget.desktopPadding,
          child: isCompact
              ? _buildScrollbar(
                  controller: _mobileScrollController,
                  child: SingleChildScrollView(
                    controller: _mobileScrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        widget.leftPanel,
                        SizedBox(height: widget.mobileGap),
                        SizedBox(
                          height: resolvedMobilePreviewHeight,
                          child: widget.rightPanel,
                        ),
                      ],
                    ),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: widget.leftFlex,
                      child: _buildScrollbar(
                        controller: _desktopLeftScrollController,
                        child: SingleChildScrollView(
                          controller: _desktopLeftScrollController,
                          child: widget.leftPanel,
                        ),
                      ),
                    ),
                    SizedBox(width: widget.desktopGap),
                    Expanded(
                      flex: widget.rightFlex,
                      child: widget.rightPanel,
                    ),
                  ],
                ),
        );
      },
    );
  }
}
