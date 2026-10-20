"""A tiny Nori SDK playground. Run with: python main.py"""

import asyncio

from nori_sdk.mock import mock_session
from nori_sdk.motion import JogBuilder, joints_by_group

# Start experimenting here. Jog speed is a normalized rate, not metres/second.
BASE_SPEED = 0.2  # -1 (backward) to 1 (forward)
DRIVE_SECONDS = 0.5
GRIPPER_POSITION = 30.0  # absolute target in the mock's 0–100 range


async def main() -> None:
    # 1. Connect to an in-memory robot. No hardware, credentials, or network.
    async with mock_session() as robot:
        info = await robot.wait_ready()
        descriptor = info.descriptor
        if descriptor is None:
            raise RuntimeError("This example needs a robot descriptor.")
        print(f"Joint groups: {joints_by_group(descriptor)}")

        # A connection alone does not mean the motion system is ready.
        if robot.daemon_status is None or not robot.daemon_status.online:
            raise RuntimeError("The motion system is not online.")

        try:
            # 2. Move the base. jog() repeats the command, then sends a stop.
            jog = JogBuilder(descriptor).base(linear=BASE_SPEED).build()
            await robot.jog(jog, duration=DRIVE_SECONDS)
            print(f"Drove the mock base for {DRIVE_SECONDS} seconds.")

            # 3. Find a gripper in the descriptor and set an absolute position.
            gripper = next(
                (joint for joint in descriptor.joints if joint.endswith("_gripper.pos")),
                None,
            )
            if gripper is not None:
                result = await robot.action({gripper: GRIPPER_POSITION}, wait=True)
                if result is None or not result.succeeded:
                    raise RuntimeError(f"Gripper did not reach its target: {result}")
                print(f"{gripper} -> {GRIPPER_POSITION}: {result.state}")

            # 4. Read one fresh update. The timeout keeps a missing stream bounded.
            async with asyncio.timeout(5):
                async for telemetry in robot.stream("telemetry"):
                    print(f"Safety: {telemetry.safety}")
                    if gripper is not None:
                        print(f"Measured gripper: {telemetry.state.get(gripper)}")
                    break
        finally:
            # 5. Ask for a stop even on errors, and await telemetry confirmation.
            await robot.estop_confirmed()
            print("E-stop confirmed; the mock session will now close.")


if __name__ == "__main__":
    asyncio.run(main())
