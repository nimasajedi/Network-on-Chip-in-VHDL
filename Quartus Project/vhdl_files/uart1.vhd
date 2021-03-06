-- UART module - example of an IP core that could be connected to network
-- complies with the interface defined by the slave NA
-- uses sc_uart.vhd and fifo.vhd to implement the UART connection
-- 
-- incoming writes will be sent to the UART
-- incoming read_requests will be replied to with a read_return 
-- where the data is the last character received by the UART

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart1 is
generic(
	node_ID : std_logic_vector(3 downto 0)
	);
port (
	clk     : in std_logic;
	nreset: in std_logic;

	txd : out std_logic;
	rxd : in std_logic;

	-- to network adapter
	na_busy			: out std_logic;
	na_read_data	: out std_logic_vector(7 downto 0);
	na_read_return	: out std_logic;
	
	-- from network adapter
	na_wr			: in std_logic;
	na_write_data	: in std_logic_vector(7 downto 0);
	na_rd			: in std_logic;
	na_addr			: in std_logic_vector(31 downto 0);
	na_read_request : in std_logic;
	
	led_out : out std_logic_vector(7 downto 0) --debugging

);
end uart1;


architecture rtl of uart1 is

	component sc_uart is
	generic (addr_bits : integer;
			 clk_freq : integer;
			 baud_rate : integer;
			 txf_depth : integer; txf_thres : integer;
			 rxf_depth : integer; rxf_thres : integer);
	port (
		clk		: in std_logic;
		reset	: in std_logic;
		address		: in std_logic_vector(addr_bits-1 downto 0);
		wr_data		: in std_logic_vector(31 downto 0);
		rd, wr		: in std_logic;
		rd_data		: out std_logic_vector(31 downto 0);
		rdy_cnt		: out unsigned(1 downto 0);

		txd		: out std_logic;
		rxd		: in std_logic;
		ncts	: in std_logic;
		nrts	: out std_logic
		);
	end component;


	signal rdy_cnt		: unsigned(1 downto 0);
	constant CLK_FREQ : integer := 50000000;
	constant BLINK_FREQ : integer := 1;
	constant CNT_MAX : integer := (CLK_FREQ/BLINK_FREQ/2-1);
	signal cnt      : unsigned(24 downto 0);
	signal blink    : std_logic;
	signal wr_data : std_logic_vector(31 downto 0);
	signal rd_data		: std_logic_vector(31 downto 0);
	signal rd : std_logic;
	signal wr : std_logic;
	signal number, numberreg: unsigned(31 downto 0);
	signal addr: std_logic_vector(0 downto 0);

	signal read_register: std_logic_vector(7 downto 0) := "00001111";


	signal wr_data_reg: std_logic_vector(7 downto 0);
	signal want_to_send: std_logic;
	signal wr_sent:	std_logic;

	--state machine
	type state_type is (POLL_STATE, WRITE_STATE, READ_STATE, DELAY_STATE);
	signal state_reg: state_type;
	signal next_state: state_type;
	
	
	
	--debugging
	signal counter : std_logic_vector(7 downto 0);

begin
	uart2: sc_uart 
	generic map(
		 addr_bits => 1,--addr_bits : integer;
		 clk_freq => 50000000,--clk_freq : integer;
		 baud_rate => 115200, --baud_rate : integer;
		 --baud_rate => 19200, --baud_rate : integer;
		 txf_depth => 32, --txf_depth : integer; txf_thres : integer;
		 rxf_depth => 32, --rxf_depth : integer; rxf_thres : integer);
		 txf_thres => 16, -- : integer;
		 rxf_thres  => 16 --: integer);
	)
	port map (
		clk => clk, 									-- clock
		reset => '0', 									-- reset
		address => addr, 									-- address
		wr_data => wr_data, 									-- wr data
		rd =>rd, 									-- rd
		wr => wr,									--wr
		rd_data => rd_data, 									-- rd data
		rdy_cnt => rdy_cnt, 									--rdy_cnt		: out unsigned(1 downto 0);
		txd => txd,									--txd		: out std_logic;
		rxd =>  rxd,									--rxd		: in std_logic;
		ncts =>'0',									--ncts	: in std_logic;
		nrts =>open										--nrts	: out std_logic
	);



	--state register
	process(clk, nreset)
	begin
		if nreset = '0' then
			state_reg<= POLL_STATE;
			numberreg <= "00000000000000000000000000000000";
		elsif rising_edge(clk) then
			state_reg<= next_state;
		end if;
	end process;
	
	--output of state machine
	process(state_reg, rd_data(0), numberreg) begin
		--number <= numberreg;
		wr_data <= (others => '0');
		wr_data(7 downto 0) <=  wr_data_reg;
		read_register <= read_register;	
		
		if nreset = '0' then
			read_register <= x"00";
		else
			
			case state_reg is
				when WRITE_STATE =>
					-- set control bits
					addr <= "1";
					wr <= '1';
					rd <= '0';					
					wr_sent <= '1';
					
					-- next state
					next_state <= DELAY_STATE;
				when READ_STATE =>
					-- set control bits
					addr <= "1";
					wr <= '0';
					rd <= '1';
				
					-- do something with read_data
					read_register <= rd_data(7 downto 0);
				
					next_state <= DELAY_STATE;
										
				when DELAY_STATE =>
					-- set control bits
					addr <= "0";
					wr <= '0';
					rd <= '1';
					
					wr_sent <= '0';
					
					next_state <= POLL_STATE;
				when POLL_STATE =>
					-- set control bits
					addr <= "0";
					wr <= '0';
					rd <= '1';
					
					-- calculate next state
					if rd_data(1) = '1' then
						next_state <= READ_STATE;
					elsif want_to_send = '1' and rd_data(0) = '1' then
						next_state <= WRITE_STATE;
					else
						next_state <= POLL_STATE;
					end if;	
					
			end case;
		end if;
	end process;


	-- listen for incoming writes from network adapter
	process(clk,na_wr, wr_sent)
	begin
		if rising_edge(clk) then
			if nreset = '0' then
				want_to_send <= '0';
				wr_data_reg	<= x"00";
				na_read_return <= '0';
			else
				-- write has been sent, reset flag
				if wr_sent = '1' then
					want_to_send <= '0';
				end if;
				
				-- incoming write 
				if na_wr = '1' then
					want_to_send <= '1';
					wr_data_reg <= na_write_data;
					na_read_return <= '0';
					
				-- incoming read request
				elsif na_read_request = '1' then
					-- TODO decode address

					na_read_data <= read_register;
					na_read_return <= '1';
					counter <= std_logic_vector(unsigned(counter)+1);
					
				else
					na_read_return <= '0';
				end if;					
			end if;	
			
			
		end if;
	
	end process;
	
	--led_out <= wr_data_reg;


	led_out <= counter;



end rtl;





