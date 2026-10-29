import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/phone_utils.dart';

/// Big left-aligned title with emoji + grey subtitle.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.emoji,
  });

  final String title;
  final String subtitle;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          emoji == null ? title : '$title $emoji',
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Nigerian phone input with flag + +234 prefix.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.onChanged,
    this.readOnly = false,
    this.errorText,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      readOnly: readOnly,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ],
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: '801 234 5678',
        errorText: errorText,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 20, right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NigeriaFlag(),
              SizedBox(width: 8),
              Text(
                PhoneUtils.dialCode,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drawn flag so it renders the same on every platform (no emoji font needed).
class _NigeriaFlag extends StatelessWidget {
  const _NigeriaFlag();

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF008751);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: 24,
        height: 16,
        child: Row(
          children: [
            Expanded(child: Container(color: green)),
            Expanded(child: Container(color: Colors.white)),
            Expanded(child: Container(color: green)),
          ],
        ),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('or', style: TextStyle(color: AppColors.textSecondary)),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
}

enum SocialProvider { google, apple }

class SocialButton extends StatelessWidget {
  const SocialButton({super.key, required this.provider});

  final SocialProvider provider;

  @override
  Widget build(BuildContext context) {
    final (Widget icon, String label) = switch (provider) {
      SocialProvider.google => (
        const FaIcon(
          FontAwesomeIcons.google,
          color: Color(0xFFDB4437),
          size: 20,
        ),
        'Continue with Google',
      ),
      SocialProvider.apple => (
        const FaIcon(FontAwesomeIcons.apple, size: 22),
        'Continue with Apple',
      ),
    };

    return SizedBox(
      height: 58,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Social sign-in will be enabled with Supabase'),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          shape: const StadiumBorder(),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            SizedBox(width: 24, child: Center(child: icon)),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 32),
          ],
        ),
      ),
    );
  }
}

/// Fixed bottom bar with a top divider, used for the main action button.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: child,
        ),
      ),
    );
  }
}
