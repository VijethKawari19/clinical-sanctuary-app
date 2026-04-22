import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth/auth_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/clinician/clinician_shell.dart';
import '../screens/clinician/pages/case_review_page.dart';
import '../screens/clinician/pages/dashboard_page.dart';
import '../screens/clinician/pages/patient_queue_page.dart';
import '../screens/clinician/pages/audit_logs_page.dart';
import '../screens/clinician/pages/settings_page.dart';
import '../screens/clinician/pages/simple_info_page.dart';
import '../screens/clinician/pages/tutorial_page.dart';
import '../screens/worker/capture_screen.dart';
import '../screens/worker/patient_info_screen.dart';
import '../screens/worker/processing_screen.dart';
import '../screens/worker/submission_success_screen.dart';
import '../screens/worker/consent_screen.dart';
import '../screens/worker/qc_processing_screen.dart';
import '../screens/worker/qc_fail_screen.dart';
import '../screens/worker/health_worker_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/auth',
  routes: [
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/auth/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => HealthWorkerShell(child: child),
      routes: [
        GoRoute(
          path: '/w/consent',
          builder: (context, state) => const ConsentScreen(),
        ),
        GoRoute(
          path: '/w/capture',
          builder: (context, state) => const CaptureScreen(),
        ),
        GoRoute(
          path: '/w/qc',
          builder: (context, state) => const QcProcessingScreen(),
        ),
        GoRoute(
          path: '/w/qc-fail',
          builder: (context, state) =>
              QcFailScreen(reason: state.extra as String),
        ),
        GoRoute(
          path: '/w/patient-info',
          builder: (context, state) => const PatientInfoScreen(),
        ),
        GoRoute(
          path: '/w/processing/:caseId',
          builder: (context, state) =>
              ProcessingScreen(caseId: state.pathParameters['caseId']!),
        ),
        GoRoute(
          path: '/w/success/:caseId',
          builder: (context, state) =>
              SubmissionSuccessScreen(caseId: state.pathParameters['caseId']!),
        ),
      ],
    ),
    ShellRoute(
      builder: (context, state, child) => ClinicianShell(child: child),
      routes: [
        GoRoute(
          path: '/c/dashboard',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: const ClinicianDashboardPage(),
          ),
        ),
        GoRoute(
          path: '/c/queue',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: const PatientQueuePage(),
          ),
        ),
        GoRoute(
          path: '/c/case/:caseId',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: CaseReviewPage(caseId: state.pathParameters['caseId']!),
          ),
        ),
        GoRoute(
          path: '/c/settings',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: const ClinicianSettingsPage(),
          ),
        ),
        GoRoute(
          path: '/c/settings/audit-logs',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: const AuditLogsPage(),
          ),
        ),
        GoRoute(
          path: '/c/settings/tutorial',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: const TutorialPage(),
          ),
        ),
        GoRoute(
          path: '/c/settings/privacy',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: const SimpleInfoPage(
              title: 'Privacy Policy',
              body:
                  'This will open your privacy policy. We can load it from the backend or a hosted URL.',
            ),
          ),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: Text(state.error.toString())),
  ),
);

