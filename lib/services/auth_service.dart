import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_core/amplify_core.dart';

class AuthService {
  static const String _userPoolId =
      'us-east-1_EN5lKzo0m'; // Replace with your User Pool ID
  static const String _clientId =
      '5q4anpk5dom2md9q7udb4vd5lo'; // Replace with your App Client ID
  static const String _region = 'us-east-1';

  /// Configures the native Amplify plugin with your AWS infrastructure settings
  static Future<void> initializeAmplify() async {
    if (Amplify.isConfigured) return;

    final authPlugin = AmplifyAuthCognito();
    await Amplify.addPlugin(authPlugin);

    // Manual configuration string matching your serverless deployment parameters
    const amplifyConfig =
        '''{
      "UserAgent": "aws-amplify-cli/2.0",
      "Version": "1.0",
      "auth": {
        "plugins": {
          "awsCognitoAuthPlugin": {
            "CognitoUserPool": {
              "Default": {
                "PoolId": "$_userPoolId",
                "AppClientId": "$_clientId",
                "Region": "$_region"
              }
            }
          }
        }
      }
    }''';

    try {
      await Amplify.configure(amplifyConfig);
      print('Amplify successfully configured with Amazon Cognito.');
    } catch (e) {
      print('Error configuring Amplify: $e');
    }
  }

  static Future<bool> signUpUser(String email, String password) async {
    try {
      final result = await Amplify.Auth.signUp(
        username: email.trim(),
        password: password,
        // FIX: You must explicitly pass the email attribute parameter metadata
        options: SignUpOptions(
          userAttributes: {AuthUserAttributeKey.email: email.trim()},
        ),
      );

      // STABLE CHECK: In modern Amplify, check if the next step is awaiting confirmation code
      return result.nextStep.signUpStep == AuthSignUpStep.confirmSignUp ||
          result.isSignUpComplete;
    } catch (e) {
      print('Sign up pipeline failure details: $e');
      return false;
    }
  }

  /// Confirms the user account using the 6-digit email verification code sent by Cognito
  static Future<bool> confirmSignUp(
    String email,
    String confirmationCode,
  ) async {
    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: email,
        confirmationCode: confirmationCode,
      );
      return result.isSignUpComplete;
    } catch (e) {
      print('Verification verification failure: $e');
      return false;
    }
  }

  /// Logs the user in and extracts the true raw cryptographic string payload
  static Future<String?> signInUser(String email, String password) async {
    try {
      final result = await Amplify.Auth.signIn(
        username: email.trim(),
        password: password,
      );
      if (result.isSignedIn) {
        final cognitoAuthSession =
            await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
        // REASON: .raw extracts the pure, un-wrapped cryptographic JWT string directly!
        final String rawTokenString =
            cognitoAuthSession.userPoolTokensResult.value.idToken.raw;

        print(
          "VERIFIED CLEAN TOKEN: $rawTokenString",
        ); // This will print a clean 'eyJ...' string
        return rawTokenString;
      }
      return null;
    } catch (e) {
      print('Sign in failure: $e');
      return null;
    }
  }
}
