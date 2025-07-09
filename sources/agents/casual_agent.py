import asyncio
import logging

from sources.utility import pretty_print, animate_thinking
from sources.agents.agent import Agent
from sources.tools.searxSearch import searxSearch
from sources.tools.flightSearch import FlightSearch
from sources.tools.fileFinder import FileFinder
from sources.tools.BashInterpreter import BashInterpreter
from sources.memory import Memory

# Get logger for casual agent
logger = logging.getLogger(__name__)

class CasualAgent(Agent):
    def __init__(self, name, prompt_path, provider, verbose=False):
        """
        The casual agent is a special for casual talk to the user without specific tasks.
        """
        super().__init__(name, prompt_path, provider, verbose, None)
        self.tools = {
        } # No tools for the casual agent
        self.role = "talk"
        self.type = "casual_agent"
        self.memory = Memory(self.load_prompt(prompt_path),
                                recover_last_session=False, # session recovery in handled by the interaction class
                                memory_compression=False,
                                model_provider=provider.get_model_name())
    
    async def process(self, prompt, speech_module) -> str:
        logger.info(f"[CasualAgent] Processing prompt: {prompt[:100]}...")
        self.memory.push('user', prompt)
        animate_thinking("Thinking...", color="status")
        logger.debug(f"[CasualAgent] Making LLM request...")
        answer, reasoning = await self.llm_request()
        logger.info(f"[CasualAgent] LLM response received. Answer length: {len(answer) if answer else 0}")
        logger.debug(f"[CasualAgent] Reasoning: {reasoning[:200] if reasoning else 'None'}...")
        self.last_answer = answer
        self.status_message = "Ready"
        logger.info(f"[CasualAgent] Processing completed")
        return answer, reasoning

if __name__ == "__main__":
    pass