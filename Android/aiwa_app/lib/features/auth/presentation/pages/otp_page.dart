import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/step_header.dart';

class OtpPage extends StatefulWidget {
  final String identifier;
  final String role;
  final String mode;

  const OtpPage({
    super.key,
    required this.identifier,
    required this.role,
    required this.mode,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _controller = TextEditingController();
  int _seconds = 45;
  Timer? _timer;

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
    super.dispose();
  }

  void _verify() {
    if (_controller.text.length != 6) return;
    context.read<AuthBloc>().add(
      AuthVerifyOtpEvent(phone: widget.identifier, code: _controller.text),
    );
  }

  PinTheme _pinTheme(Color border) => PinTheme(
    width: 44,
    height: 54,
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
          _controller.clear();
          setState(() {});
        }
      },
      child: AuthStepScaffold(
        bottom: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => AiwaButton(
            label: 'Verify',
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
            title: 'Enter the code',
            subtitle: 'We sent a 6-digit code to ${widget.identifier}.',
            onBack: () => context.pop(),
          ),
          const SizedBox(height: 26),
          Center(
            child: Pinput(
              length: 6,
              controller: _controller,
              autofocus: true,
              separatorBuilder: (_) => const SizedBox(width: 8),
              defaultPinTheme: _pinTheme(AppColors.divider),
              focusedPinTheme: _pinTheme(AppColors.plum700),
              submittedPinTheme: _pinTheme(AppColors.plum700),
              onChanged: (_) => setState(() {}),
              onCompleted: (_) => _verify(),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: _seconds > 0
                ? Text.rich(
                    TextSpan(
                      text: 'Resend code in ',
                      style: AppTextStyles.meta,
                      children: [
                        TextSpan(
                          text: '0:${_seconds.toString().padLeft(2, '0')}',
                          style: AppTextStyles.mono.copyWith(
                            color: AppColors.plum900,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: () {
                      _controller.clear();
                      _startTimer();
                      context.read<AuthBloc>().add(
                        AuthSendOtpEvent(phone: widget.identifier),
                      );
                    },
                    child: Text(
                      'Resend code',
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
                    "Didn't get it? Check the number, then tap Resend once the timer ends.",
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
