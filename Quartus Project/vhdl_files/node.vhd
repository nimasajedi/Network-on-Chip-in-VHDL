-- instantiates a device, network adapter and router
-- joins the 3 modules together with appropriate signals

-- different types of nodes can be created with the "node_type" signal
	-- type 0 = dummy_proc + na_master + router
	-- type 1 = dummy_slave + na_slave + router
	-- type 2 = uart1 + na_slave + router
	-- type 3 = router only
	-- type 4 = switches


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity node is
generic (
	node_type : integer;
	node_ID : std_logic_vector(3 downto 0);
	proc_type : integer --only used for dummy_proc (node_type 0)
);

port (
	clk     : in std_logic;
	nreset	: in std_logic;
	
	--busy signals 		- 0 = local, 1 = north, 2 = east, 3 = south, 4 = west
	busy_in 			: in std_logic_vector(4 downto 1);
	busy_out 		: out std_logic_vector(4 downto 1);
	
	local_busy_in	: out std_logic; --output used for traffic counters - only needed internally otherwise
	local_busy_out	: out std_logic; --output used for traffic counters - only needed internally otherwise
	
	--router packet connections
	north_pkt_in 	: in std_logic_vector(48 downto 0);
	north_pkt_out 	: out std_logic_vector(48 downto 0);
	
	east_pkt_in 	: in std_logic_vector(48 downto 0);
	east_pkt_out 	: out std_logic_vector(48 downto 0);
	
	south_pkt_in 	: in std_logic_vector(48 downto 0);
	south_pkt_out 	: out std_logic_vector(48 downto 0);
	
	west_pkt_in 	: in std_logic_vector(48 downto 0);
	west_pkt_out 	: out std_logic_vector(48 downto 0);
	
	led_output	: out std_logic_vector(7 downto 0);
	
	uart_txd 	: out std_logic;
	uart_rxd 	: in std_logic;
	
	
	test_leds			: out std_logic_vector(7 downto 0);
	
	switches_in		: in std_logic_vector(7 downto 0) --used by switches component only
);
end node;



architecture rtl of node is

--=================================================================================================
		
	-- router component
	component router is
	generic (
		node_ID 	: std_logic_vector(3 downto 0)
	);
	port (
		clk     	: in std_logic;
		nreset	: in std_logic;
		
		--busy signals 		- 0 = local, 1 = north, 2 = east, 3 = south, 4 = west
		busy_in 			: in std_logic_vector(4 downto 0);
		busy_out 		: out std_logic_vector(4 downto 0);

		local_pkt_in 	: in std_logic_vector(48 downto 0);
		local_pkt_out 	: out std_logic_vector(48 downto 0);
		
		north_pkt_in 	: in std_logic_vector(48 downto 0);
		north_pkt_out 	: out std_logic_vector(48 downto 0);
		
		east_pkt_in 	: in std_logic_vector(48 downto 0);
		east_pkt_out 	: out std_logic_vector(48 downto 0);
		
		south_pkt_in 	: in std_logic_vector(48 downto 0);
		south_pkt_out 	: out std_logic_vector(48 downto 0);
		
		west_pkt_in 	: in std_logic_vector(48 downto 0);
		west_pkt_out 	: out std_logic_vector(48 downto 0)
		
	);
	end component;
	
	--router signals
	signal local_pkt_in		: std_logic_vector(48 downto 0);
	signal local_pkt_out	: std_logic_vector(48 downto 0);
	
	signal local_busy_in_signal	:std_logic;
	signal local_busy_out_signal	:std_logic;
	
--=================================================================================================

	-- dummy_proc node components
	component dummy_proc is
	generic(
		node_ID : std_logic_vector(3 downto 0);
		proc_type : integer
	);
	port (
		clk     		: in std_logic;
		nreset			: in std_logic;		
		dest_addr 		: out std_logic_vector(31 downto 0);			
		-- write signals (and dest_addr)
		wr_data			: out std_logic_vector(7 downto 0);
		wr				: out std_logic;		
		-- read request signals (and dest_addr)
		read_request	: out std_logic;		
		-- read return signals
		rd_data 		: in std_logic_vector(7 downto 0);
		read_return			: in std_logic;		
		-- NA busy, don't send more requests
		not_ready			: in std_logic;
		
		
		test_leds			: out std_logic_vector(7 downto 0)
	);
	end component;

	component na_master is
	generic (
		node_ID		 		: std_logic_vector(3 downto 0)
	);
	port (
		clk					: in std_logic;
		nreset				: in std_logic;
		busy				: in std_logic;											-- busy signal from the router
		address 			: in std_logic_vector(31 downto 0);
		write_en			: in std_logic;
		read_request 		: in std_logic;
		write_data		 	: in std_logic_vector(7 downto 0);
		packet_data_in		: in std_logic_vector(48 downto 0);	
		packet_data_out 	: out std_logic_vector(48 downto 0);					-- packet sent to router
		not_ready			: out std_logic;
		read_return			: out std_logic;
		read_data			: out std_logic_vector(7 downto 0)
		
		
	);
	end component;

	-- dummy_proc signals
	
	-- between dummy_proc and na_master (used by others too)
	signal address 		: std_logic_vector(31 downto 0);
	signal write_data	: std_logic_vector(7 downto 0); 
	signal write_enable	: std_logic;
	signal read_request : std_logic;
	signal read_data	: std_logic_vector(7 downto 0);
	signal read_return	: std_logic;
	signal not_ready	: std_logic;
	
	-- between na_master and router
	-- TODO

--=================================================================================================

	-- dummy_slave node components
	component dummy_slave is
	generic(
			node_ID : std_logic_vector(3 downto 0)
			);
	port (
		clk     : in std_logic;
		nreset	: in std_logic;
		
		led_output     : out std_logic_vector(7 downto 0);
		
		address			: in std_logic_vector(31 downto 0); -- TODO - currently not implemented
		
		-- write signals (and dest_addr)
		wr_data			: in std_logic_vector(7 downto 0);
		wr				: in std_logic;
		
		-- read request signals (and dest_addr)
		read_request	: in std_logic;	
		
		-- read return signals
		rd_data 		: out std_logic_vector(7 downto 0);
		read_return			: out std_logic	
	);
	end component;


	component na_slave is
	generic (
		node_ID		 		: std_logic_vector(3 downto 0)
	);
	port (
		clk					: in std_logic;
		nreset				: in std_logic;
		
		packet_data_in		: in std_logic_vector(48 downto 0); 
		read_return			: in std_logic;
		read_data			: in std_logic_vector(7 downto 0);
		
		router_not_rdy		: in std_logic; 								-- router is busy
		slave_not_rdy		: in std_logic;								-- memory is busy
		na_not_rdy			: out std_logic;								-- network adapter is busy
		
		packet_data_out 	: out std_logic_vector(48 downto 0);	-- packet sent to router
		address 				: out std_logic_vector(31 downto 0);
		write_en				: out std_logic;
		read_request 		: out std_logic;
		write_data		 	: out std_logic_vector(7 downto 0)

	);
	end component;


--=================================================================================================

	-- uart node components
	component uart1 is
	generic(
		node_ID : std_logic_vector(3 downto 0)
		);
    port (
        clk     : in std_logic;
        nreset: in std_logic;

        txd : out std_logic;
        rxd : in std_logic;
        
        led_out : out std_logic_vector(7 downto 0);

		-- to network adapter
		na_busy			: out std_logic;
		na_read_data	: out std_logic_vector(7 downto 0);
		na_read_return	: out std_logic;
				
		-- from network adapter
		na_wr			: in std_logic;
		na_write_data	: in std_logic_vector(7 downto 0);
		na_rd			: in std_logic;
		na_addr			: in std_logic_vector(31 downto 0);
		na_read_request : in std_logic
    );
    end component;

--=================================================================================================
	--switches component	
	component switches is
	generic(
			node_ID : std_logic_vector(3 downto 0)
			);
	port (
		clk     : in std_logic;
		nreset	: in std_logic;
			
		led_output     : out std_logic_vector(7 downto 0);
		
		address			: in std_logic_vector(31 downto 0); -- TODO - currently not implemented
		
		-- write signals (and dest_addr)
		wr_data			: in std_logic_vector(7 downto 0);
		wr				: in std_logic;
		
		-- read request signals (and dest_addr)
		read_request	: in std_logic;	
		
		-- read return signals
		rd_data 		: out std_logic_vector(7 downto 0);
		read_return			: out std_logic;
		
		switches		: in std_logic_vector(7 downto 0)
		
	);
	end component;


begin

--=================================================================================================
	-- instantiate router	
	
	router_inst : router
	generic map(
		node_ID 	=> node_ID
	)
	port map(
		clk     	=> clk,
		nreset		=> nreset,
		
		--busy signals 		- 0 = local, 1 = north, 2 = east, 3 = south, 4 = west
		busy_in(4 downto 1) 		=> busy_in,
		busy_out(4 downto 1) 		=> busy_out,
		
		busy_in(0) 			=> local_busy_in_signal,
		busy_out(0) 		=> local_busy_out_signal,

		local_pkt_in 	=> local_pkt_in,
		local_pkt_out 	=> local_pkt_out,
		
		north_pkt_in 	=> north_pkt_in,
		north_pkt_out 	=> north_pkt_out,
		
		east_pkt_in 	=> east_pkt_in,
		east_pkt_out 	=> east_pkt_out,
		
		south_pkt_in 	=> south_pkt_in,
		south_pkt_out 	=> south_pkt_out,
		
		west_pkt_in 	=> west_pkt_in,
		west_pkt_out 	=> west_pkt_out
		
	);


--=================================================================================================

	-- generate master node
	gen_dummy_master : if node_type = 0 generate
	begin
		dummy_proc_inst : dummy_proc
		generic map(
			node_ID => node_ID,
			proc_type => proc_type
		)
		port map(
			clk     		=> clk,
			nreset			=> nreset,	
			dest_addr 		=> address,			
			-- write signals (and dest_addr)
			wr_data			=> write_data,
			wr				=> write_enable,		
			-- read request signals (and dest_addr)
			read_request	=> read_request,		
			-- read return signals
			rd_data 		=> read_data,
			read_return		=> read_return,	
			-- NA busy, don't send more requests
			not_ready		=> '0', -- TODO
			
			
			test_leds			=> test_leds
		);
		
		na_master_inst : na_master
		generic map (
			node_ID		 		=> node_ID
		)
		port map(
			clk					=> clk,
			nreset				=> nreset,
			busy				=> local_busy_out_signal, -- TODO										-- busy signal from the router
			address 			=> address,
			write_en			=> write_enable,
			read_request 		=> read_request,
			write_data		 	=> write_data,
			packet_data_in		=> local_pkt_out,	
			packet_data_out 	=> local_pkt_in,				-- packet sent to router
			not_ready			=> local_busy_in_signal,		--na not ready to receive from router
			read_return			=> read_return,
			read_data			=> read_data
			
			
		);
		
	end generate;

--=================================================================================================

	-- generate dummy_slave node
	gen_dummy_slave : if node_type = 1 generate
	begin
		
		
		dummy_slave_inst : dummy_slave
		generic map(
				node_ID => node_ID
				)
		port map(
			clk     => clk,
			nreset	=> nreset,
			
			led_output     => led_output,
			
			address			=> address, -- TODO - currently not implemented
			
			-- write signals (and dest_addr)
			wr_data			=> write_data,
			wr				=> write_enable,
			
			-- read request signals (and dest_addr)
			read_request	=> read_request,	
			
			-- read return signals
			rd_data 			=> read_data,
			read_return			=> read_return	
		);
		
		na_slave_inst : na_slave
		generic map (
			node_ID		 		=> node_ID
		)
		port map(
			clk					=> clk,
			nreset				=> nreset,
			packet_data_in		=> local_pkt_out, 
			read_return			=> read_return,
			read_data			=> read_data,
			
			router_not_rdy		=> local_busy_out_signal, 								-- router is busy
			slave_not_rdy		=> '0',--TODO								-- memory is busy
			na_not_rdy			=> local_busy_in_signal,								-- network adapter is busy
			
			packet_data_out 	=> local_pkt_in,	-- packet sent to router
			address 			=> address,
			write_en			=> write_enable,
			read_request 		=> read_request,
			write_data		 	=> write_data

		);
		
		
	end generate;
	
--=================================================================================================

	-- generate uart node
	gen_uart : if node_type = 2 generate
	begin
	
		na_slave_inst : na_slave
		generic map (
			node_ID		 		=> node_ID
		)
		port map(
			clk					=> clk,
			nreset				=> nreset,
			packet_data_in		=> local_pkt_out, 
			read_return			=> read_return,
			read_data			=> read_data,
			
			router_not_rdy		=> local_busy_out_signal, 								-- router is busy
			slave_not_rdy		=> '0',--TODO								-- memory is busy
			na_not_rdy			=> local_busy_in_signal,							-- network adapter is busy
			
			packet_data_out 	=> local_pkt_in,	-- packet sent to router
			address 			=> address,
			write_en			=> write_enable,
			read_request 		=> read_request,
			write_data		 	=> write_data

		);
		
		uart1_inst : uart1
		generic map(
			node_ID => node_ID
			)
		port map(
			clk     	=> clk,
			nreset 		=> nreset,

			txd 		=> uart_txd,
			rxd 		=> uart_rxd,

			led_out 	=> led_output,
			
			-- to network adapter
			na_busy			=> open, --TODO
			na_read_data	=> read_data,
			na_read_return	=> read_return,
			
			-- from network adapter
			na_wr			=> write_enable,
			na_write_data	=> write_data,
			na_rd			=> read_request,
			na_addr			=> address,
		    na_read_request => read_request
		);
		
	end generate;
	
--=================================================================================================
	
	--switches
	gen_switches : if node_type = 4 generate
	begin
	
		switches_inst : switches
		generic map(
				node_ID => node_ID
				)
		port map(
			clk     => clk,
			nreset	=> nreset,
			
			led_output     => led_output,
			
			address			=> address, -- TODO - currently not implemented
			
			-- write signals (and dest_addr)
			wr_data			=> write_data,
			wr				=> write_enable,
			
			-- read request signals (and dest_addr)
			read_request	=> read_request,	
			
			-- read return signals
			rd_data 			=> read_data,
			read_return			=> read_return,
			
			switches		=> switches_in
		);
		
		na_slave_inst : na_slave
		generic map (
			node_ID		 		=> node_ID
		)
		port map(
			clk					=> clk,
			nreset				=> nreset,
			packet_data_in		=> local_pkt_out, 
			read_return			=> read_return,
			read_data			=> read_data,
			
			router_not_rdy		=> local_busy_out_signal, 								-- router is busy
			slave_not_rdy		=> '0',								-- memory is busy
			na_not_rdy			=> local_busy_in_signal,--TODO								-- network adapter is busy
			
			packet_data_out 	=> local_pkt_in,	-- packet sent to router
			address 			=> address,
			write_en			=> write_enable,
			read_request 		=> read_request,
			write_data		 	=> write_data

		);
		

	
	end generate;

	--router only
	gen_router_only : if node_type = 3 generate
	begin
	--router declared seperately up the top (used by all node types)
		local_pkt_in <= (others => '0');
		local_busy_in_signal <= '0';
		
	end generate;
	
	--connect busy signals
	local_busy_in <= local_busy_in_signal;
	local_busy_out <= local_busy_out_signal;



end rtl;





