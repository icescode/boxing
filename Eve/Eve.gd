extends KinematicBody

#Figthing State
enum  {
	IDLE,
	PUNCH,
	DOUBLE_PUNCH,
	UPPER_CUT,
	BLOCK
}
#if player punch the opponent, what kind of hand she uses
const SENDER_R_HAND := "Right Hand"
const SENDER_L_HAND := "Left Hand"
const SENDER_R_FORE_ARM := "Right Fore Arm"
const SENDER_L_FORE_ARM := "Left Fore Arm"

#collision shape target punch
const TARGET_BODY_POINT := "TargetBodyPoint"
const TARGET_HEAD_POINT := "TargetHeadPoint"

const MIN_RANGE_BETWEEN_FIGHTER := 10
const TIMER_TICK_TIME := 0.5
var animTree : AnimationTree
var walk := true
var timer:Timer

#opponent must be a KinematicBody too
var _opponentKinematic : KinematicBody
var boxingState : int
var attackState : Array = [PUNCH, DOUBLE_PUNCH, UPPER_CUT]

export(NodePath) var opponentSelector setget set_opponent

#the lines of code below was borrowed from
#Garbaj Channel
#https://www.youtube.com/watch?v=YFgrpp1fpOI&list=PLZlYha_B4PAFlCqzYcb4xD2S6wRoa-us4
onready var nav = get_parent()
var path = []
var path_node = 0
var speed = 20
var catchme_range :float 
#end of Garbaj

func set_opponent(kb:NodePath) :
	opponentSelector = kb
	property_list_changed_notify()
			
func _ready():
	
	_opponentKinematic = get_node(opponentSelector)
	
	if _opponentKinematic != null :
		timer = Timer.new()
		var err  = timer.connect("timeout",self,"_on_timer_timeout")
		if err == OK :
			timer.set_wait_time(TIMER_TICK_TIME)
			add_child(timer)
			timer.start()
			animTree = $AnimationStateTree
			animTree.active = true
			boxingState = IDLE
		else :
			printerr("Timer can not run")		
	else :
		printerr("Opponnet not set!")	
	
	
func _on_timer_timeout():
	#calculate distance between two or more fighters
	catchme_range = global_transform.origin.distance_squared_to(_opponentKinematic.global_transform.origin)	
	
	#move to opponent location, and start boxing if range is below 10
	if ceil(catchme_range) > MIN_RANGE_BETWEEN_FIGHTER :
		move_to(_opponentKinematic.global_transform.origin)	
	else :
		#if the direction of fighter are not facing each other
		#rotate the fighter
		
		var dot = global_transform.origin.normalized().dot(_opponentKinematic.global_transform.origin.normalized())
		
		#According to Godot's Documentation about Vector3 dot :
		#When using unit (normalized) vectors, the result will always be between -1.0 (180 degree angle) 
		#when the vectors are facing opposite directions, and 1.0 (0 degree angle) when the vectors are aligned.

		if dot > -1 :
			#absolutely  tweaks is needed (better codes) , not sure how yet
			look_at_from_position(global_transform.origin,_opponentKinematic.global_transform.origin,Vector3.UP)
			rotate_y(deg2rad(180))			
				
	if !walk :		
		#randomize boxingState :))
		boxingState = randi() % 4 + 1	
		
#		if boxingState in attackState :
#			_opponentKinematic.boxingState = BLOCK

		#i don't know if those lines of code below is necessary ?
		#the original is on lines [91-92]
		var randomizeFair = randi() % 2
		
		if randomizeFair == 0 :
			if boxingState in attackState :
				_opponentKinematic.boxingState = BLOCK
		else :
			if _opponentKinematic.boxingState in attackState :
				boxingState = BLOCK
			
		playTree(boxingState)

#the line of codes below was borrowed from
#Garbaj Channel
#https://www.youtube.com/watch?v=YFgrpp1fpOI&list=PLZlYha_B4PAFlCqzYcb4xD2S6wRoa-us4&index=15&t=147s
func move_to(target_pos) :
	path = nav.get_simple_path(global_transform.origin,target_pos)
	path_node = 0
#end of Garbaj

func activateFollower() :
	#follow target hit to Skeleton
	$TargetHeadPoint.global_transform = $Skeleton/BAHead/AnchorHead/CSHead.global_transform
	$TargetBodyPoint.global_transform = $Skeleton/BABody/AnchorBody/CSBody.global_transform

func _physics_process(_delta):
	
	activateFollower()
	#if there are enemy[ies]
	if _opponentKinematic :		
		#RayCast's location is a child of Skeleton/BAHead
		var opponentCollider = $Skeleton/BAHead/RayCast.get_collider()
		#if opponentCollider is not null that means they are in boxing range
		#then stop walk, just fight each other
		if opponentCollider and opponentCollider.get_owner().name == _opponentKinematic.name:	
			walk = false			
		else :
			#go find opponenent's location
			if walk :
#the line of codes below was borrowed from
#Garbaj Channel
#https://www.youtube.com/watch?v=YFgrpp1fpOI&list=PLZlYha_B4PAFlCqzYcb4xD2S6wRoa-us4
				if path_node < path.size() :
					var direction = (path[path_node] - global_transform.origin)
					if direction.length() < 1:
						path_node += 1
					else :
						if !timer.is_stopped() :
							var	_ret = move_and_slide(direction.normalized() * speed, Vector3.UP)
#end of Garbaj						
	
#the character and animations is from Mixamo https://mixamo.com
#combiner software is using https://nilooy.github.io/character-animation-combiner
#running from my local Linux
func playTree(mode : int) :	
#all animations are on one shot mode
#and the default loop animation is Idle animation
	match mode :
		BLOCK :
			animTree.set("parameters/StateSelector/blend_amount",1)
			animTree.set("parameters/Defense/Block/active",true)
			
		PUNCH :
			animTree.set("parameters/StateSelector/blend_amount",0)
			animTree.set("parameters/AttackBlender/blend_amount",0)
			animTree.set("parameters/Punch/active",true)
			
		DOUBLE_PUNCH :
			animTree.set("parameters/StateSelector/blend_amount",0)
			animTree.set("parameters/AttackBlender/blend_amount",1)
			animTree.set("parameters/DoublePunch/active",true)
			
		UPPER_CUT :
			animTree.set("parameters/StateSelector/blend_amount",0)
			animTree.set("parameters/AttackBlender/blend_amount",-1)
			animTree.set("parameters/UpperCut/active",true)

#SIGNAL							
func _on_RightHandArea_body_entered(body):
	handEvents(body,SENDER_R_HAND)

func _on_LeftHandArea_body_entered(body):
	handEvents(body,SENDER_L_HAND)

func _on_RightForeArm_body_entered(body):
	handEvents(body,SENDER_R_FORE_ARM)

func _on_LeftForeArm_body_entered(body):
	handEvents(body,SENDER_L_FORE_ARM)

func handEvents(body : Node,sender : String) :	
	#body.name == opponent , name = this
	if body.name != name :
		#which one is hit, Head or Body
		var index_body = body.get_index()
		var target_hit = body.get_child(index_body)
		
		#dont count as hit if the opponent is on block state
		if body.boxingState != BLOCK :
			#only if body and head
			if str(target_hit.name) == TARGET_HEAD_POINT or str(target_hit.name) == TARGET_BODY_POINT :
				var message : String
				
				#i count fore-arm as cheat
				if sender == SENDER_L_FORE_ARM or sender == SENDER_R_FORE_ARM :
					message = body.name + " cheat using " + sender
					
				else :					
					message = name + " hit " + body.name + " at " + target_hit.name + " using " + sender
				
				#IDLE her as a simulation if someone got hits
				body.playTree(IDLE)
				sendReportEvents(message)
		else :
			sendReportEvents(body.name + " blocking " + name)

#I'am an old school of Objective-C years ago
#this thing is very easy if using delegate/observer..etc
#there is signal in Godot's world that i believe that is a right tool for this ? , but i'm not understand the how to yet
func sendReportEvents(msg : String) :
	if msg :
		var parent = get_tree().current_scene
		if parent :
			var infoLabel = parent.get_node("Info/LabelInfo")		
			if infoLabel :
				infoLabel.text = msg
	
