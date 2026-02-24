import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobo_billing/providers/profile_provider.dart';
import 'package:mobo_billing/screens/profile/profile_screen.dart';
import 'package:mobo_billing/widgets/circular_image_widget.dart';

class ProfileAvatarWidget extends StatelessWidget {
  final double radius;
  final double iconSize;

  const ProfileAvatarWidget({Key? key, this.radius = 16, this.iconSize = 18})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        final profile = profileProvider.profile;

        final rawImage = profile?['image_128'];
        final profileImage = rawImage is String ? rawImage : null;

        if (profile == null &&
            !profileProvider.isLoading &&
            !profileProvider.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            profileProvider.loadProfile();
          });
        }

        final displayName = (profile?['name'] as String? ?? '').trim();

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: CircularImageWidget(
                base64Image: profileImage,
                radius: radius,
                fallbackText: displayName,
                backgroundColor: Theme.of(context).primaryColor,
                textColor: Colors.white,
                isLoading: profileProvider.isLoading,
              ),
            ),
          ),
        );
      },
    );
  }
}
