import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 앱을 처음 켰을 때 1초 동안 로고를 보여준 뒤 홈으로 이동하는 스플래시 화면.
/// 초보자도 이해할 수 있도록, 각 단계마다 어떤 일이 일어나는지 한글 주석을 최대한 자세히 작성한다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // ▼ 앱 시작 시 1초 동안 로고만 보여주기 위해 Future.delayed를 사용한다.
    //    Duration(seconds: 1)을 주면 1초가 지난 뒤에 콜백이 실행된다.
    Future.delayed(const Duration(seconds: 1), () {
      // ▼ Future가 실행되는 동안 사용자가 다른 화면으로 이동하면 context가 사라질 수 있으므로,
      //    mounted 여부를 확인하여 안전하게 라우팅을 진행한다.
      if (!mounted) return;

      // ▼ 준비된 홈 화면은 '/home' 경로에 연결해 두었으므로, 스플래시 종료 시 그쪽으로 이동한다.
      //    go_router의 context.go는 현재 화면을 대체하고 새 라우트를 스택 최상단으로 만든다.
      context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        // ▼ 기존 자산 폴더에 있는 앱 로고 이미지를 사용해 사용자가 앱을 알아볼 수 있도록 한다.
        //    Image.asset은 pubspec.yaml에 등록된 자산을 읽어온다.
        child: Image.asset(
          'assets/icon/app_icon.png',
          width: 120,
          height: 120,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
