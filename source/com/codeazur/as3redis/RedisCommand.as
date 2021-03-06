﻿package com.codeazur.as3redis 
{
	import flash.utils.ByteArray;
	import flash.utils.IDataOutput;
	import flash.utils.getTimer;
	
	public class RedisCommand
	{
		public static const RESPONSE_TYPE_UNDEFINED:String = "responseTypeUndefined";
		public static const RESPONSE_TYPE_ERROR:String = "responseTypeError";
		public static const RESPONSE_TYPE_STRING:String = "responseTypeString";
		public static const RESPONSE_TYPE_INTEGER:String = "responseTypeInteger";
		public static const RESPONSE_TYPE_BULK:String = "responseTypeBulk";
		public static const RESPONSE_TYPE_BULK_MULTI:String = "responseTypeBulkMulti";
		
		protected var responders:Vector.<RedisResponder>;
		
		protected var _request:ByteArray;
		protected var _responseType:String = RESPONSE_TYPE_UNDEFINED;
		protected var _responseMessage:String = "";
		protected var _responseBulk:Vector.<ByteArray>;
		protected var _responseBulkAsStrings:Array;
		
		protected var _roundtrip:Number = -1.0;

		protected var starttime:Number = 0.0;
		
		public function RedisCommand()
		{
		}
		
		public function get responseType():String { return _responseType; }
		public function get responseMessage():String { return _responseMessage; }
		public function get responseBulk():Vector.<ByteArray> { return _responseBulk; }

		public function get roundtrip():Number { return _roundtrip; }

		public function get responseBulkAsStrings():Array {
			if (_responseBulkAsStrings == null) {
				if (_responseBulk != null && _responseBulk.length > 0) {
					_responseBulkAsStrings = [];
					var val:String;
					for (var i:uint = 0; i < _responseBulk.length; i++) {
						val = null;
						var ba:ByteArray = _responseBulk[i];
						if (ba != null) {
							if (ba.length > 0) {
								ba.position = 0;
								val = ba.readUTFBytes(ba.length);
							} else {
								val = "";
							}
						}
						_responseBulkAsStrings.push(val);
					}
				}
			}
			return _responseBulkAsStrings;
		}
		
		public function get name():String {
			// Override in subclasses
			throw(new Error("Please override the name getter."));
		}
		
		public function send(stream:IDataOutput):void {
			// Override in subclasses (call super!)
			starttime = getTimer();
		}
		
		internal function setResponseType(value:String):void {
			_responseType = value;
		}

		internal function setResponseMessage(value:String):void {
			_responseMessage = value;
		}

		internal function addBulkResponse(response:ByteArray):void {
			_responseBulkAsStrings = null;
			if (_responseBulk == null) {
				_responseBulk = Vector.<ByteArray>( [ response ] );
			} else {
				_responseBulk.push(response);
			}
			processBulkResponse(response);
		}

		internal function removeAllBulkResponses():void {
			_responseBulk = null;
		}
		
		protected function processBulkResponse(response:ByteArray):void {
			// Override in subclasses
		}

		protected function serializeValue(value:*):ByteArray {
			var ba:ByteArray = new ByteArray();
			if (value is String || value is Number || value is Boolean) {
				ba.writeUTFBytes(String(value));
			} else if (value is ByteArray) {
				ba = value as ByteArray;
			} else {
				ba.writeObject(value);
			}
			return ba;
		}
		
		protected function toStringValue(value:*):String {
			var s:String;
			if (value is String || value is Number || value is Boolean) {
				s = String(value);
				if (s.length == 0) {
					s = "<empty>";
				}
			} else if (value is ByteArray) {
				s = "<binary:" + ByteArray(value).length + ">";
			} else if (value == null || value == undefined) {
				s = "<null>";
			} else {
				s = "<object>";
			}
			return s;
		}
		
		public function addResponder(responder:RedisResponder):void {
			if (responders == null) {
				responders = Vector.<RedisResponder>( [ responder ] );
			} else {
				responders.push(responder);
			}
		}
		
		public function addSimpleResponder(result:Function, fault:Function = null):void {
			addResponder(new RedisResponder(result, fault));
		}
		
		public function removeAllResponders():void {
			responders = null;
		}
		
		public function hasResponders():Boolean {
			return (responders != null) && (responders.length > 0);
		}
		
		public function result():void {
			_roundtrip = getTimer() - starttime;
			if (hasResponders()) {
				for (var i:uint = 0; i < responders.length; i++) {
					if (responders[i].result != null) {
						responders[i].result(this);
					}
				}
			}
		}
		
		public function fault():void {
			_roundtrip = getTimer() - starttime;
			if (hasResponders()) {
				for (var i:uint = 0; i < responders.length; i++) {
					if (responders[i].status != null) {
						responders[i].status(this);
					}
				}
			}
		}

		public function toString():String {
			var t:String = (roundtrip == -1) ? "" : " (" + roundtrip + " ms)";
			var s:String = toStringCommand() + t;
			if (_responseMessage != null && _responseMessage.length > 0) {
				s += "\n  " + _responseMessage;
			}
			if (responseBulkAsStrings != null) {
				for (var i:uint = 0; i < responseBulkAsStrings.length; i++) {
					var val:String = responseBulkAsStrings[i];
					if (val == null) {
						val = "<null>";
					} else if (val == "") {
						val = "<empty>";
					}
					s += "\n  " + i + ": " + val;
				}
			}
			return s;
		}

		public function toStringCommand():String {
			return "[" + name + "]";
		}
	}
}
