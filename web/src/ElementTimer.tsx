import React, { useState, useEffect } from "react";
// 필요한 이미지들을 전역 assets/icon 경로에서 불러온다
import ellipse42 from "../../assets/icon/ellipse-42.svg";
import ellipse from "../../assets/icon/ellipse.svg";
import location from "../../assets/icon/location.svg";
import batteryIcon from "../../assets/icon/battery.svg";
import statusBarService from "../../assets/icon/status-bar-service.svg";

// 타이머 화면 컴포넌트
export const ElementTimer = (): JSX.Element => {
  // 남은 시간을 초 단위로 관리 (초보자도 이해하기 쉽게 32분 10초를 그대로 계산)
  const [timeRemaining, setTimeRemaining] = useState(32 * 60 + 10);
  // 타이머가 동작 중인지 여부
  const [isRunning, setIsRunning] = useState(true);

  // 컴포넌트가 마운트되거나 상태가 변경될 때마다 실행되는 훅
  useEffect(() => {
    let interval: NodeJS.Timeout; // setInterval의 반환값을 저장하기 위한 변수

    // 타이머가 실행 중이며 남은 시간이 있을 때만 1초마다 감소
    if (isRunning && timeRemaining > 0) {
      interval = setInterval(() => {
        setTimeRemaining((prev) => prev - 1); // 이전 값에서 1초 감소
      }, 1000); // 1000ms = 1초 간격
    }

    // 타이머 정리: 컴포넌트가 사라지거나 조건이 바뀌면 인터벌을 해제
    return () => clearInterval(interval);
  }, [isRunning, timeRemaining]);

  // 초 단위의 숫자를 "분:초" 형태의 문자열로 변환
  const formatTime = (seconds: number): string => {
    const minutes = Math.floor(seconds / 60); // 전체 분 계산
    const remainingSeconds = seconds % 60; // 남은 초 계산
    // padStart를 사용해 한 자릿수 초 앞에 0을 붙여 항상 두 자리로 표시
    return `${minutes}:${remainingSeconds.toString().padStart(2, "0")}`;
  };

  // 완료(Finish) 버튼을 눌렀을 때 실행될 함수
  const handleFinish = () => {
    setIsRunning(false); // 타이머를 멈춘다
    // TODO: 완료 처리 로직을 여기에 추가
  };

  // 종료(Quit) 버튼을 눌렀을 때 실행될 함수
  const handleQuit = () => {
    setIsRunning(false); // 타이머를 멈춘다
    // TODO: 종료 처리 로직을 여기에 추가
  };

  return (
    <div className="bg-[#fafaff] grid justify-items-center [align-items:start] w-screen">
      <div className="bg-[#fafaff] w-[375px] h-[812px] relative">
        <div className="absolute w-[375px] h-[752px] top-[60px] left-0">
          <div className="absolute w-[375px] h-[752px] top-0 left-0 bg-white">
            {/* 종료 버튼 */}
            <button
              onClick={handleQuit}
              className="absolute top-[629px] left-[170px] opacity-70 [font-family:'Rubik-Regular',Helvetica] font-normal text-[#070417] text-lg text-center tracking-[0] leading-5 whitespace-nowrap cursor-pointer hover:opacity-100 transition-opacity"
            >
              Quit
            </button>

            {/* 완료 버튼 */}
            <button
              onClick={handleFinish}
              className="all-[unset] box-border inline-flex flex-col items-center gap-2.5 px-[121px] py-5 absolute top-[546px] left-10 bg-[#e8e8ff] rounded-lg overflow-hidden cursor-pointer hover:bg-[#dcdcff] transition-colors"
            >
              <div className="relative w-fit mt-[-1.00px] [font-family:'Rubik-Medium',Helvetica] font-medium text-black text-lg text-center tracking-[0] leading-5 whitespace-nowrap">
                Finish
              </div>
            </button>

            {/* 타이머 표시 영역 */}
            <div className="absolute w-[222px] h-[220px] top-[226px] left-[77px]">
              <div className="relative w-[220px] h-[220px] bg-[url(/ellipse-41.svg)] bg-[100%_100%]">
                {/* 보라색 진행 원 그래픽 */}
                <img
                  className="absolute w-[182px] h-[220px] top-0 left-[38px]"
                  alt="Timer progress indicator"
                  src={ellipse42}
                />

                {/* 남은 시간 표시 */}
                <div className="w-[120px] top-[94px] left-[50px] [font-family:'Rubik-Medium',Helvetica] text-[40px] tracking-[2.00px] leading-8 absolute font-medium text-[#070417] text-center whitespace-nowrap">
                  {formatTime(timeRemaining)}
                </div>
              </div>
            </div>

            {/* 작업 카테고리 태그 */}
            <div className="inline-flex flex-col items-center gap-2.5 px-2 py-[5px] absolute top-[68px] left-[308px] bg-[#ffeff1] rounded-md overflow-hidden">
              <div className="relative w-fit mt-[-1.00px] [font-family:'Rubik-Regular',Helvetica] font-normal text-pink text-xs tracking-[0] leading-[14px] whitespace-nowrap">
                Work
              </div>
            </div>

            {/* 프로젝트 이름과 카테고리 표시 */}
            <div className="absolute w-[92px] h-5 top-[106px] left-6">
              <img
                className="absolute w-4 h-4 top-0.5 left-0"
                alt="Project category indicator"
                src={ellipse}
              />

              <div className="absolute top-0 left-7 [font-family:'Rubik-Regular',Helvetica] font-normal text-[#070417] text-sm tracking-[0] leading-5 whitespace-nowrap">
                UI Design
              </div>
            </div>

            <h1 className="absolute top-[69px] left-6 [font-family:'Rubik-Medium',Helvetica] font-medium text-[#070417] text-2xl tracking-[0] leading-5 whitespace-nowrap">
              Rasion Project
            </h1>

            <div className="absolute w-10 h-1 top-4 left-[167px] bg-[#e8e8ff] rounded-lg" />
          </div>

          <div className="absolute w-[135px] h-[5px] top-[739px] left-[120px] bg-[#3a3a3a1a] rounded-[100px]" />
        </div>

        <header className="absolute w-[375px] h-11 top-0 left-0">
          {/* 배터리 이미지를 Figma에서 받은 원형 그래픽으로 교체 */}
          <img
            className="absolute w-[27px] h-5 top-[13px] left-[334px]"
            alt="Battery status indicator"
            src={batteryIcon}
          />

          <div className="absolute w-[41px] h-5 top-[13px] left-[292px]">
            <img
              className="absolute w-[17px] h-2.5 top-[5px] left-0.5"
              alt="Network signal strength"
              src={statusBarService}
            />
          </div>

          <div className="absolute w-[57px] h-5 top-[13px] left-[21px]">
            <div className="absolute w-4 h-4 top-0.5 left-10">
              <img
                className="absolute w-2.5 h-2.5 top-1 left-0.5"
                alt="Location services indicator"
                src={location}
              />
            </div>

            <time className="-top-px left-0.5 [font-family:'SF_Pro_Display-Medium',Helvetica] text-[15px] tracking-[-0.24px] leading-5 absolute font-medium text-[#070417] text-center whitespace-nowrap">
              12:22
            </time>
          </div>
        </header>
      </div>
    </div>
  );
};
