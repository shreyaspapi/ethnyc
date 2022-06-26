//import { Button, Card, DatePicker, Divider, Input, Progress, Slider, Spin, Switch, Row, Col } from "antd";
import React, { useState, useEffect } from "react";

import "bootstrap/dist/css/bootstrap.min.css";

import { Card, Row, Col, Button, Alert, Form, InputGroup, Spinner, Divider } from "react-bootstrap";

import { Address, Balance, Events, AddressInput } from "../components";

import { INFURA_ID } from "../constants";

import { ethers } from "ethers";

import { Framework } from "@superfluid-finance/sdk-core";

// Ethers.js provider initialization
const customHttpProvider = new ethers.providers.InfuraProvider("rinkeby", INFURA_ID);

export default function CreateStream() {
  return <div>hey</div>;
}

/* export default function ExistingStreams() {

  const [streams, setStreams] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function fetchData() {
      const sf = await Framework.create({
        chainId: 4,
        provider: customHttpProvider,
      });

      const signer = sf.createSigner({
        privateKey: "ae4b6f52bfbdeadbca2901f6776c0411bdff7b482192fb6743d755a52a1995c3",
        provider: customHttpProvider,
      });

      const ETHxContraactAddress = await sf.loadSuperToken("ETHx");
      const ETHx = ETHxContraactAddress.address;

      const getStreamsOperation = sf.cfaV1.getStreams({
        superToken: ETHx,
      });

      const result = await getStreamsOperation.exec(signer);

      const streams = await sf.cfaV1.getFlow({
        superToken: string,
        sender: string,
        receiver: string,
        providerOrSigner: ethers.providers.Provider | ethers.Signer,
      });

      console;
      console.log(streams);

      setStreams(result);
      setLoading(false);
    }
    fetchData();
  }, []);

  if (loading) {
    return (
      <div>
        <Spinner animation="border" variant="primary" />
      </div>
    );
  }

  if (error) {
    return (
      <div>
        <Alert variant="danger">{error}</Alert>
      </div>
    );
  }

  return (
    <div>
      <h2>Existing Streams:</h2>
      <div style={{ border: "1px solid #cccccc", padding: 16, width: 400, margin: "auto", marginTop: 64 }}>
        {streams.map(stream => (
          <div key={stream.id}>
            <h4>Stream ID: {stream.id}</h4>
            <h4>Sender: {stream.sender}</h4>
            <h4>Receiver: {stream.receiver}</h4>
            <h4>Flow Rate: {stream.flowRate}</h4>
            <h4>Created At: {stream.createdAt}</h4>
          </div>
        ))}
      </div>
    </div>
  );
}
 */
