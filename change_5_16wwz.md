# change on 5.16
## add file snake_controller/food_generator/collision_checker/game_fsm
## VGA 修改部分
删除83~85 188~198行关于food部分，统一在food_generator里进行coding。\
106~108 173~186蛇长控制，由snake_controller管理。\
109死亡检测由collision_checker接管。


## snake_controller

是主要的逻辑控制模块，管理蛇的位置、长度、移动和增长逻辑,实现贪吃蛇的核心行为（前进、吃食物、变长）,支持游戏初始化和运行状态。
***端口说明：***

**输入端口：**
clk：时钟信号。\
rst_n：异步复位信号（低有效）。\
general_state：游戏状态（"10"=初始化，"11"=运行）。\
move_state：控制蛇移动方向的信号（如上/下/左/右）。\
flag_update：在每一帧信号为1时，更新蛇的位置。\
flag_eat：吃到食物时为1，蛇会变长。

**输出端口：**
snake_length：当前蛇的长度。\
snake_x、snake_y：蛇每节身体的X/Y坐标（最多20节，每节10位二进制表示）。


***控制逻辑***
移动控制过程：
1. 复位时
长度初始化为3。所有蛇的身体初始化在一条水平线上（x坐标逐渐减小，y=240）。

2. 时钟上升沿
如果 general_state = "10"，重新初始化蛇的长度和方向。\
如果 general_state = "11"，表示游戏进行中：

    若方向不是 STOP，更新方向。

    若 flag_update = '1'，表示需要移动一帧：

        从尾到头依次移动身体（后面的身体跟随前面的坐标）。

        蛇头根据当前方向移动一格（SQUARE_LEN）。

        如果 flag_eat = '1'，并且没有达到最大长度，蛇的长度加一节。


## food_generator
吃食物逻辑：
1. 判断蛇是否吃到了食物。
2. 当吃到食物或初始化时，生成一个新的食物坐标。
3. 输出食物的坐标，以及吃到食物的标志 flag_eat。

***控制逻辑***
1. 吃：
    如果蛇头坐标等于食物坐标，并且游戏状态为 "11"（游戏中），则 flag_eat_r 置为 '1'。\
    否则 flag_eat_r 清零。
2. 生成：
    吃到了食物 (flag_eat_r = '1')。
    游戏初始化 (general_state = "10")。

## collision_checker
碰撞检测的组件。在每个时钟周期检查蛇是否：

    撞墙（边界）

    撞到自己（身体）

    如果任意一种碰撞发生，则输出 is_dead = '1'，表示蛇死亡。

## game_fsm
有限状态机（FSM）控制器，用于管理游戏的运行状态。模式：

    等待开始（IDLE）、

    初始化阶段（INIT_GAME）、

    正常运行中（RUNNING）

状态的转换基于玩家输入和游戏逻辑。



### 待解决问题
食物生成在自己身上
计分系统还没写