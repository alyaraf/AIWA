import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/step_header.dart';
import 'package:aiwa_app/l10n/l10n.dart';

class OtpPage extends StatefulWidget {
  final String identifier;
  final String role;
  final String mode;

  /// Destination as the user typed it ('+20 100 555 8821').
  final String? display;

  const OtpPage({
    super.key,
    required this.identifier,
    required this.role,
    required this.mode,
    this.display,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  int _seconds = 45;
  Timer? _timer;
  String? _error;

  bool get _isProvider => widget.role == 'PROVIDER';
  int get _totalSteps => _isProvider ? 6 : 4;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_seconds <= 0) {
        t.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _verify() {
    if (_controller.text.length != 6) return;
    setState(() => _error = null);
    context.read<AuthBloc>().add(
      AuthVerifyOtpEvent(phone: widget.identifier, code: _controller.text),
    );
  }

  PinTheme _pinTheme(Color border, double width) => PinTheme(
    width: width,
    height: width * 1.15,
    textStyle: AppTextStyles.h2.copyWith(
      fontSize: 28,
      color: AppColors.plum900,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
    decoration: BoxDecoration(
      color: AppColors.paper,
      border: Border.all(color: border, width: 1.5),
      borderRadius: BorderRadius.circular(14),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, _) => ModalRoute.of(context)?.isCurrent ?? false,
      listener: (context, state) {
        if (state is AuthOtpVerified) {
          context.push(
            AppRoutes.accountSetup,
            extra: {
              'role': widget.role,
              'identifier': widget.identifier,
              'mode': widget.mode,
            },
          );
        } else if (state is AuthError) {
          _controller.clear();
          setState(
            () => _error = AppLocalizations.of(context).error(state.message),
          );
        }
      },
      child: AuthStepScaffold(
        bottom: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => AiwaButton(
            label: AppLocalizations.of(context).authVerify,
            fullWidth: true,
            size: AiwaButtonSize.lg,
            loading: state is AuthLoading,
            onPressed: _controller.text.length == 6 ? _verify : null,
          ),
        ),
        children: [
          StepHeader(
            step: 2,
            total: _totalSteps,
            title: AppLocalizations.of(context).authEnterCode,
            subtitleSpans: spansOf(
              AppLocalizations.of(context).authCodeSentTo('{destination}'),
              {
                'destination': TextSpan(
                  // LTR isolate keeps '+20 …' intact inside Arabic text.
                  text: '\u2066${widget.display ?? widget.identifier}\u2069',
                  style: TextStyle(
                    color: AppColors.plum900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              },
            ),
            onBack: () => context.pop(),
          ),
          const SizedBox(height: 26),
          // Cells span the width, 8px apart, 1:1.15 (auth-screens.jsx:258-272).
          LayoutBuilder(
            builder: (context, bc) {
              final w = (bc.maxWidth - 5 * 8) / 6;
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Pinput(
                  length: 6,
                  controller: _controller,
                  focusNode: _focus,
                  separatorBuilder: (_) => const SizedBox(width: 8),
                  defaultPinTheme: _pinTheme(AppColors.divider, w),
                  focusedPinTheme: _pinTheme(AppColors.divider, w),
                  submittedPinTheme: _pinTheme(AppColors.plum700, w),
                  onChanged: (_) => setState(() => _error = null),
                ),
              );
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            InlineBanner(
              tone: BannerTone.danger,
              icon: Icons.error_outline_rounded,
              body: _error,
              compact: true,
            ),
          ],
          const SizedBox(height: 18),
          Center(
            child: _seconds > 0
                ? Text.rich(
                    TextSpan(
                      style: AppTextStyles.meta,
                      children: spansOf(
                        AppLocalizations.of(context).authResendIn('{time}'),
                        {
                          'time': TextSpan(
                            text: '0:${_seconds.toString().padLeft(2, '0')}',
                            style: AppTextStyles.mono.copyWith(
                              color: AppColors.plum900,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        },
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () {
                      _controller.clear();
                      setState(() => _error = null);
                      _focus.requestFocus();
                      _startTimer();
                      context.read<AuthBloc>().add(
                        AuthSendOtpEvent(phone: widget.identifier),
                      );
                    },
                    child: Text(
                      AppLocalizations.of(context).authResendCode,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.plum700,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cream,
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.plum700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).authOtpHelp,
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.ink2,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
