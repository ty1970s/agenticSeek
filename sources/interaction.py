import readline
import logging
from typing import List, Tuple, Type, Dict

from sources.text_to_speech import Speech
from sources.utility import pretty_print, animate_thinking
from sources.router import AgentRouter
from sources.speech_to_text import AudioTranscriber, AudioRecorder
import threading

# Get logger for interaction
logger = logging.getLogger(__name__)


class Interaction:
    """
    Interaction is a class that handles the interaction between the user and the agents.
    """
    def __init__(self, agents,
                 tts_enabled: bool = True,
                 stt_enabled: bool = True,
                 recover_last_session: bool = False,
                 langs: List[str] = ["en", "zh"]
                ):
        self.is_active = True
        self.current_agent = None
        self.last_query = None
        self.last_answer = None
        self.last_reasoning = None
        self.last_success = True
        self.agents = agents
        self.tts_enabled = tts_enabled
        self.stt_enabled = stt_enabled
        self.recover_last_session = recover_last_session
        self.router = AgentRouter(self.agents, supported_language=langs)
        self.ai_name = self.find_ai_name()
        self.speech = None
        self.transcriber = None
        self.recorder = None
        self.is_generating = False
        self.languages = langs
        self.response_language = "auto"  # 新增回复语言设置
        if tts_enabled:
            self.initialize_tts()
        if stt_enabled:
            self.initialize_stt()
        if recover_last_session:
            self.load_last_session()
        self.emit_status()
    
    def get_spoken_language(self) -> str:
        """Get the primary TTS language."""
        lang = self.languages[0]
        return lang

    def initialize_tts(self):
        """Initialize TTS."""
        if not self.speech:
            animate_thinking("Initializing text-to-speech...", color="status")
            self.speech = Speech(enable=self.tts_enabled, language=self.get_spoken_language(), voice_idx=1)

    def initialize_stt(self):
        """Initialize STT."""
        if not self.transcriber or not self.recorder:
            animate_thinking("Initializing speech recognition...", color="status")
            self.transcriber = AudioTranscriber(self.ai_name, verbose=False)
            self.recorder = AudioRecorder()
    
    def emit_status(self):
        """Print the current status of agenticSeek."""
        if self.stt_enabled:
            pretty_print(f"Text-to-speech trigger is {self.ai_name}", color="status")
        if self.tts_enabled:
            self.speech.speak("Hello, we are online and ready. What can I do for you ?")
        pretty_print("AgenticSeek is ready.", color="status")
    
    def find_ai_name(self) -> str:
        """Find the name of the default AI. It is required for STT as a trigger word."""
        ai_name = "jarvis"
        for agent in self.agents:
            if agent.type == "casual_agent":
                ai_name = agent.agent_name
                break
        return ai_name
    
    def get_last_blocks_result(self) -> List[Dict]:
        """Get the last blocks result."""
        if self.current_agent is None:
            return []
        blks = []
        for agent in self.agents:
            blks.extend(agent.get_blocks_result())
        return blks
    
    def load_last_session(self):
        """Recover the last session."""
        for agent in self.agents:
            if agent.type == "planner_agent":
                continue
            agent.memory.load_memory(agent.type)
    
    def save_session(self):
        """Save the current session."""
        for agent in self.agents:
            agent.memory.save_memory(agent.type)

    def is_active(self) -> bool:
        return self.is_active
    
    def read_stdin(self) -> str:
        """Read the input from the user."""
        buffer = ""

        PROMPT = "\033[1;35m➤➤➤ \033[0m"
        while not buffer:
            try:
                buffer = input(PROMPT)
            except EOFError:
                return None
            if buffer == "exit" or buffer == "goodbye":
                return None
        return buffer
    
    def transcription_job(self) -> str:
        """Transcribe the audio from the microphone."""
        self.recorder = AudioRecorder(verbose=True)
        self.transcriber = AudioTranscriber(self.ai_name, verbose=True)
        self.transcriber.start()
        self.recorder.start()
        self.recorder.join()
        self.transcriber.join()
        query = self.transcriber.get_transcript()
        if query == "exit" or query == "goodbye":
            return None
        return query

    def get_user(self) -> str:
        """Get the user input from the microphone or the keyboard."""
        if self.stt_enabled:
            query = "TTS transcription of user: " + self.transcription_job()
        else:
            query = self.read_stdin()
        if query is None:
            self.is_active = False
            self.last_query = None
            return None
        self.last_query = query
        return query
    
    def set_query(self, query: str) -> None:
        """Set the query"""
        self.is_active = True
        self.last_query = query
    
    def _add_language_instruction(self, query: str) -> str:
        """根据设定的回复语言添加语言指令到查询中。"""
        if self.response_language == "auto":
            return query
        
        # 语言代码到指令的映射
        language_instructions = {
            "zh-CN": "请用简体中文回复。",
            "zh-TW": "請用繁體中文回覆。",
            "en": "Please reply in English.",
            "ja": "日本語で回答してください。",
            "ko": "한국어로 답변해 주세요.",
            "fr": "Veuillez répondre en français.",
            "de": "Bitte antworten Sie auf Deutsch.",
            "es": "Por favor, responda en español.",
            "pt": "Por favor, responda em português.",
            "ru": "Пожалуйста, отвечайте на русском языке.",
            "ar": "يرجى الرد باللغة العربية.",
        }
        
        language_instruction = language_instructions.get(self.response_language, "")
        if language_instruction:
            logger.info(f"[Interaction] Adding language instruction: {language_instruction}")
            return f"{query}\n\n{language_instruction}"
        
        return query
    
    async def think(self) -> bool:
        """Request AI agents to process the user input."""
        logger.info(f"[Interaction] Starting think process for query: {self.last_query[:100] if self.last_query else 'None'}...")
        push_last_agent_memory = False
        if self.last_query is None or len(self.last_query) == 0:
            logger.warning("[Interaction] No query provided, returning False")
            return False
        
        # Agent selection
        logger.debug("[Interaction] Selecting agent for query...")
        agent = self.router.select_agent(self.last_query)
        if agent is None:
            logger.error("[Interaction] No agent selected, returning False")
            return False
        
        logger.info(f"[Interaction] Selected agent: {agent.agent_name}")
        
        # Check if we need to push previous agent memory
        if self.current_agent != agent and self.last_answer is not None:
            logger.debug("[Interaction] Different agent selected, will push last agent memory")
            push_last_agent_memory = True
        
        tmp = self.last_answer
        self.current_agent = agent
        self.is_generating = True
        
        # 根据设定的语言添加语言指令到查询中
        query_with_language = self._add_language_instruction(self.last_query)
        
        logger.info(f"[Interaction] Starting agent processing...")
        self.last_answer, self.last_reasoning = await agent.process(query_with_language, self.speech)
        self.is_generating = False
        
        logger.info(f"[Interaction] Agent processing completed. Answer length: {len(self.last_answer) if self.last_answer else 0}")
        logger.debug(f"[Interaction] Agent reasoning: {self.last_reasoning[:200] if self.last_reasoning else 'None'}...")
        
        if push_last_agent_memory:
            logger.debug("[Interaction] Pushing memory to current agent")
            self.current_agent.memory.push('user', self.last_query)
            self.current_agent.memory.push('assistant', self.last_answer)
        
        if self.last_answer == tmp:
            logger.debug("[Interaction] Answer unchanged, setting to None")
            self.last_answer = None
        
        logger.info("[Interaction] Think process completed successfully")
        return True
    
    def get_updated_process_answer(self) -> str:
        """Get the answer from the last agent."""
        if self.current_agent is None:
            return None
        return self.current_agent.get_last_answer()
    
    def get_updated_block_answer(self) -> str:
        """Get the answer from the last agent."""
        if self.current_agent is None:
            return None
        return self.current_agent.get_last_block_answer()
    
    def speak_answer(self) -> None:
        """Speak the answer to the user in a non-blocking thread."""
        if self.last_query is None:
            return
        if self.tts_enabled and self.last_answer and self.speech:
            def speak_in_thread(speech_instance, text):
                speech_instance.speak(text)
            thread = threading.Thread(target=speak_in_thread, args=(self.speech, self.last_answer))
            thread.start()
    
    def show_answer(self) -> None:
        """Show the answer to the user."""
        if self.last_query is None:
            return
        if self.current_agent is not None:
            self.current_agent.show_answer()

